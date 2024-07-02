#include "metal_stdlib"
#include "shaderTypes.h"
using namespace metal;

struct v2f {
    float4 position [[position]];
    float3 entryPoint;
};

struct v2fBlit {
  float4 position [[position]];
    ushort amp_id;
};

v2f vertex vertexMain( uint vertexId [[vertex_id]],
                      ushort amp_id [[amplification_id]],
                      device const float4* position [[buffer(0)]],
                      device const float4* position1 [[buffer(1)]],
                      device const MatricesArray& matricesArray [[buffer(2)]])
{
    shaderMatrices matrices = matricesArray.matrices[amp_id];
    if (amp_id == 0) {
        position = position1;
    }
    
    v2f o;
    o.position = matrices.modelViewProjection * position[ vertexId ];
    o.entryPoint = (matrices.clip*position[ vertexId ]).xyz+0.5;
    return o;
}

float transferFunction(float v, ShaderRenderParamaters params) {
    v = clamp((v - params.smoothStepStart) / params.smoothStepShift, 0.0, 1.0);
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

half4 fragment fragmentMainStandard( v2f in [[stage_in]],
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

half4 fragment fragmentMainISO( v2f in [[stage_in]],
                               ushort amp_id [[amplification_id]],
                               texture3d< half, access::sample > volume [[texture(0)]],
                               device const ParamsArray& renderArray [[buffer(0)]])
{
    
    ShaderRenderParamaters renderParams = renderArray.params[amp_id];
    const float iso = renderParams.smoothStepStart;
    
    constexpr sampler s( address::clamp_to_border, filter::linear );
    float3 voxelCount = float3(volume.get_width(), volume.get_height(), volume.get_depth());
    
    float3 rayDirectionInTextureSpace = normalize(in.entryPoint-renderParams.cameraPosInTextureSpace);
    
    // compute delta
    float samples = dot(abs(rayDirectionInTextureSpace),voxelCount);
    float3 delta = rayDirectionInTextureSpace/(samples*renderParams.oversampling);
    
    float3 currentPoint = in.entryPoint;
    float4 result = 0.0;
    do {
        float volumeValue = volume.sample( s, currentPoint ).r;
        currentPoint += delta;
        float4 current = float4(volumeValue);
        
        if (current.a >= iso) {
            return half4( half3(current.rgb) ,1 );
        }
    } while (inBounds(currentPoint,renderParams));
    
    return half4( result );
}

half4 fragment fragmentMainISOLighting( v2f in [[stage_in]],
                                       ushort amp_id [[amplification_id]],
                                       texture3d< half, access::sample > volume [[texture(0)]],
                                       device const ParamsArray& renderArray [[buffer(0)]])
{
    ShaderRenderParamaters renderParams = renderArray.params[amp_id];
    const float iso = renderParams.smoothStepStart;
    
    constexpr sampler s( address::clamp_to_border, filter::linear );
    float3 voxelCount = float3(volume.get_width(), volume.get_height(), volume.get_depth());
    
    float3 rayDirectionInTextureSpace = normalize(in.entryPoint-renderParams.cameraPosInTextureSpace);
    
    // compute delta
    float samples = dot(abs(rayDirectionInTextureSpace),voxelCount);
    float3 delta = rayDirectionInTextureSpace/(samples*renderParams.oversampling);
    
    float3 currentPoint = in.entryPoint;
    float4 result = 0.0;
    do {
        float volumeValue = volume.sample( s, currentPoint ).r;
        currentPoint += delta;
        float4 current = float4(volumeValue);
        
        if (current.a >= iso) {
            float3 normal = computeNormal(currentPoint, voxelCount, float3(1,1,1), volume);
            current.rgb = lighting((renderParams.modelView*float4((currentPoint-0.5)*2,1)).xyz,
                                   (renderParams.modelViewIT*float4(normal,0)).xyz, float3(0.5,0.5,0.5));
            return half4( half3(current.rgb) ,1 );
        }
    } while (inBounds(currentPoint,renderParams));
    
    return half4( result );
}

struct QuadMRTOut {
  float4 mrt0 [[ color(0) ]];
  float4 mrt1 [[ color(1) ]];
  float4 mrt2 [[ color(2) ]];
  float4 mrt3 [[ color(3) ]];
};

QuadMRTOut fragment fragmentMainClearView( v2f in [[stage_in]],
                                   texture3d< half, access::sample > volume [[texture(0)]],
                                   device const ShaderRenderParamaters& renderParams [[buffer(0)]])
{
    QuadMRTOut out;
    out.mrt0 = float4( 0 );
    out.mrt1 = float4( 0 );
    out.mrt2 = float4( 0 );
    out.mrt3 = float4( 0 );

    constexpr sampler s( address::clamp_to_border, filter::linear );
    float3 voxelCount = float3(volume.get_width(), volume.get_height(), volume.get_depth());

    float3 rayDirectionInTextureSpace = normalize(in.entryPoint-renderParams.cameraPosInTextureSpace);

    // compute delta
    float samples = dot(abs(rayDirectionInTextureSpace),voxelCount);
    float3 delta = rayDirectionInTextureSpace/(samples*renderParams.oversampling);

    float3 currentPoint = in.entryPoint;
    do {
      float volumeValue = volume.sample( s, currentPoint ).r;
      if (volumeValue >= renderParams.smoothStepStart) {
          out.mrt0 = float4(currentPoint,1);
          out.mrt1 = float4(computeNormal(currentPoint, voxelCount, float3(1,1,1), volume),1.0);
          break;
      }
      currentPoint += delta;
    } while (inBounds(currentPoint,renderParams));

    do {
      float volumeValue = volume.sample( s, currentPoint ).r;
      if (volumeValue >= renderParams.smoothStepShift) {
          out.mrt2 = float4(currentPoint,1);
          out.mrt3 = float4(computeNormal(currentPoint, voxelCount, float3(1,1,1), volume),1.0);
          return out;
      }
      currentPoint += delta;
    } while (inBounds(currentPoint,renderParams));

    return out;
}

float computeCurvatureApprox(ushort2 fragPos, float3 centerNormal, texture2d< float, access::read > normalTex) {

  float3 normalXp = normalTex.read(fragPos+ushort2( 1, 0)).xyz;
  float3 normalXn = normalTex.read(fragPos+ushort2(-1, 0)).xyz;
  float3 normalYp = normalTex.read(fragPos+ushort2( 0, 1)).xyz;
  float3 normalYn = normalTex.read(fragPos+ushort2( 0,-1)).xyz;

  return saturate(length(centerNormal-normalXp)+
                  length(centerNormal-normalXn)+
                  length(centerNormal-normalYp)+
                  length(centerNormal-normalYn));
}


half4 fragment fragmentMainIsoSecond( v2fBlit in [[stage_in]],
                                     ushort amp_id [[amplification_id]],
                                texture2d< float, access::read > isoPosTex0 [[texture(0)]],
                                texture2d< float, access::read > isoPosTex0_1 [[texture(1)]],
                                     
                                texture2d< float, access::read > isoNormalTex0 [[texture(2)]],
                                texture2d< float, access::read > isoNormalTex0_1 [[texture(3)]],
                                     
                                texture2d< float, access::read > isoPosTex1 [[texture(4)]],
                                texture2d< float, access::read > isoPosTex1_1 [[texture(5)]],
                                     
                                texture2d< float, access::read > isoNormalTex1 [[texture(6)]],
                                texture2d< float, access::read > isoNormalTex1_1 [[texture(7)]],
                                     
                                device const ShaderRenderParamaters& renderParams [[buffer(0)]])
{
    float eyeDistance = 125; // ???
    float xPos = renderParams.xPos;
    if (amp_id == 1) {
        isoPosTex0 = isoPosTex0_1;
        isoNormalTex0 = isoNormalTex0_1;
        isoPosTex1 = isoPosTex1_1;
        isoNormalTex1 = isoNormalTex1_1;
        
        xPos = xPos - eyeDistance;
    } else {
        xPos = xPos + eyeDistance;
    }
    
  ushort2 fragPos = ushort2(in.position.xy);

  float4 isoPos0 = isoPosTex0.read(fragPos);
  if (isoPos0.w < 0.5) return half4(0);
  float3 normal0 = isoNormalTex0.read(fragPos).xyz;
  float4 colorIso0 = float4(lighting((renderParams.modelView*float4((isoPos0.xyz-0.5)*2,1)).xyz,
                                     (renderParams.modelViewIT*float4(normal0,0)).xyz, float3(1.0,0.0,0.0)),1);
  float curvature = computeCurvatureApprox(fragPos, normal0, isoNormalTex0);

  float4 colorIso1 = float4(0);
  float4 isoPos1 = isoPosTex1.read(fragPos);
  if (isoPos1.w > 0.5) {
    float3 normal1 = isoNormalTex1.read(fragPos).xyz;
    colorIso1.xyz = lighting((renderParams.modelView*float4((isoPos1.xyz-0.5)*2,1)).xyz,
                                (renderParams.modelViewIT*float4(normal1,0)).xyz, float3(0.0,1.0,0.0));
    colorIso1.w = 1;
  }

  ushort2 centerFrag = ushort2(xPos, renderParams.yPos);
  float3 centerPos = isoPosTex0.read(centerFrag).xyz;

  float centerDistScale = saturate(length(centerPos-isoPos0.xyz)*renderParams.cvScale);
  if (centerDistScale > 0.9 && centerDistScale < 1.0) colorIso0.rgb -= 0.4;
  float weight = saturate(curvature+centerDistScale);
  return half4(mix(colorIso1, colorIso0, weight));
}

v2fBlit vertex vertexMainBlit( uint vertexId [[vertex_id]],
                              ushort amp_id [[amplification_id]],
                           device const float4* position [[buffer(0)]])
{
    v2fBlit o;
    o.position = position[ vertexId ];
    o.amp_id = amp_id;
    return o;
}

half4 fragment fragmentMainBlit( v2fBlit in [[stage_in]],
                                texture2d< float, access::read > prevPass [[texture(0)]],
                                texture2d< float, access::read > prevPass1 [[texture(1)]])
{
    if (in.amp_id == 0) {
        return half4(prevPass.read(ushort2(in.position.xy)));
    } else {
        return half4(prevPass1.read(ushort2(in.position.xy)));
    }
}
