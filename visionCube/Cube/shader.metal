#include "metal_stdlib"
#include "shaderTypes.h"
using namespace metal;

struct v2f {
    float4 position [[position]];
    float3 entryPoint;
};

v2f vertex vertexMain( uint vertexId [[vertex_id]],
                      ushort amp_id [[amplification_id]],
                      device const float4* position [[buffer(0)]],
                      device const MatricesArray& matricesArray [[buffer(1)]])
{
    shaderMatrices matrices = matricesArray.matrices[amp_id];
    v2f o;
    
    o.position = matrices.modelViewProjection * position[ vertexId ];
    o.entryPoint = (matrices.clip*position[ vertexId ]).xyz+0.5;
    return o;
}

float transferFunction(float v, ShaderRenderParamaters params) {
    v = clamp((v - params.smoothStepStart) / (params.smoothStepShift), 0.0, 1.0);
    return float(v * v * (3-2*v));
}

float4 under(float4 current, float4 last) {
    last.rgb = last.rgb + (1.0-last.a) * current.a * current.rgb;
    last.a   = last.a   + (1.0-last.a) * current.a;
    return last;
}

bool inBounds(float3 pos, ShaderRenderParamaters params) {
    return pos.x >= params.minBounds.x && pos.y >= params.minBounds.y && pos.z >= params.minBounds.z &&
    pos.x <= params.maxBounds.x && pos.y <= params.maxBounds.y && pos.z <= params.maxBounds.z;
}

float3 lighting(float3 vPosition, float3 vNormal, float3 color) {
        
    float3 vLightAmbient  = float3(0.1,0.1,0.1);
    float3 vLightDiffuse  = float3(0.5,0.5,0.5);
    float3 vLightSpecular = float3(0.8,0.8,0.8);
    float3 lightDir = float3(0.0,0.0,1.0);


    float3 vViewDir    = normalize(vPosition);
    float3 vReflection = normalize(reflect(vViewDir, vNormal));
    return clamp(color*vLightAmbient+
       color*vLightDiffuse*max(abs(dot(vNormal, lightDir)),0.0)+
       vLightSpecular*pow(max(dot(vReflection, lightDir),0.0),8.0), 0.0,1.0);
}

float3 computeGradient(float3 vCenter, float3 sampleDelta, texture3d< half, access::sample > volume [[texture(0)]]) {

    constexpr sampler s( address::clamp_to_border, filter::linear );

    float fVolumValXp = volume.sample(s, vCenter+float3(+sampleDelta.x,0,0)).r;
    float fVolumValXm = volume.sample(s, vCenter+float3(-sampleDelta.x,0,0)).r;
    float fVolumValYp = volume.sample(s, vCenter+float3(0,-sampleDelta.y,0)).r;
    float fVolumValYm = volume.sample(s, vCenter+float3(0,+sampleDelta.y,0)).r;
    float fVolumValZp = volume.sample(s, vCenter+float3(0,0,+sampleDelta.z)).r;
    float fVolumValZm = volume.sample(s, vCenter+float3(0,0,-sampleDelta.z)).r;
    return float3(fVolumValXm - fVolumValXp,
    fVolumValYp - fVolumValYm,
    fVolumValZm - fVolumValZp) / 2.0;
}

float3 computeNormal(float3 vCenter, float3 volSize, float3 DomainScale, texture3d< half, access::sample > volume [[texture(0)]]) {
    float3 vGradient = computeGradient(vCenter, 1/volSize, volume);
    float3 vNormal   = vGradient * DomainScale;
    float l = length(vNormal); if (l>0.0) vNormal /= l; // safe normalization
    return vNormal;
}

half4 fragment fragmentMain( v2f in [[stage_in]],
                            ushort amp_id [[amplification_id]],
                            texture3d< half, access::sample > volume [[texture(0)]],
                            device const ParamsArray& renderArray [[buffer(0)]])
{
    
    ShaderRenderParamaters renderParams = renderArray.params[amp_id];
    constexpr sampler s( address::clamp_to_border, filter::linear );
    float3 voxelCount = float3(volume.get_width(), volume.get_height(), volume.get_depth());
    
    float3 rayDirectionInTextureSpace = normalize(in.entryPoint-renderParams.cameraPosInTextureSpace);
    
    // compute delta
    float samples = dot(abs(rayDirectionInTextureSpace),voxelCount);
    float opacityCorrection = 100/(samples*renderParams.oversampling);
    float3 delta = rayDirectionInTextureSpace/(samples*renderParams.oversampling);
    
    float3 currentPoint = in.entryPoint;
    float4 result = 0.0;
    do {
        float volumeValue = volume.sample( s, currentPoint ).r;
        currentPoint += delta;
        float4 current = float4(volumeValue);
        current.a = transferFunction(current.a, renderParams);
        current.a = 1.0 - pow(1.0 - current.a, opacityCorrection);
        result = under(current, result);
        if (result.a > 0.95) break;
    } while (inBounds(currentPoint,renderParams));

    return half4( result );
}

half4 fragment fragmentMainLighting( v2f in [[stage_in]],
                            ushort amp_id [[amplification_id]],
                            texture3d< half, access::sample > volume [[texture(0)]],
                            device const ParamsArray& renderArray [[buffer(0)]])
{
    
    ShaderRenderParamaters renderParams = renderArray.params[amp_id];
    constexpr sampler s( address::clamp_to_border, filter::linear );
    float3 voxelCount = float3(volume.get_width(), volume.get_height(), volume.get_depth());
    
    float3 rayDirectionInTextureSpace = normalize(in.entryPoint-renderParams.cameraPosInTextureSpace);
    
    // compute delta
    float samples = dot(abs(rayDirectionInTextureSpace),voxelCount);
    float opacityCorrection = 100/(samples*renderParams.oversampling);
    float3 delta = rayDirectionInTextureSpace/(samples*renderParams.oversampling);
    
    float3 currentPoint = in.entryPoint;
    float4 result = 0.0;
    do {
        float volumeValue = volume.sample( s, currentPoint ).r;
        currentPoint += delta;
        float4 current = float4(volumeValue);
        current.a = transferFunction(current.a, renderParams);

        float3 normal = computeNormal(currentPoint, voxelCount, float3(1,1,1), volume);
        current.rgb = lighting((renderParams.modelView*float4((currentPoint-0.5)*2,1)).xyz,
                         (renderParams.modelViewIT*float4(normal,0)).xyz, current.rgb);

        current.a = 1.0 - pow(1.0 - current.a, opacityCorrection);
        result = under(current, result);
        if (result.a > 0.95) break;
    } while (inBounds(currentPoint, renderParams));

    return half4( result );
}
