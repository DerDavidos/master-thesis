#include "metal_stdlib"
using namespace metal;

struct v2f {
    float4 position [[position]];
    float3 entryPoint;
};

struct Matrices {
    float4x4 modelViewProjection;
    float4x4 clip;
};

struct RenderParams {
    float smoothStepStart;
    float smoothStepWidth;
    float oversampling;
    float3 cameraPosInTextureSpace;
    float3 minBounds;
    float3 maxBounds;
};

float4 transferFunction(float v, RenderParams params) {
    v = clamp((v - params.smoothStepWidth) / (params.smoothStepStart - params.smoothStepWidth), 0.0, 1.0);
    return float4(v*v * (3-2*v));
}

float4 under(float4 current, float4 last) {
    last.rgb = last.rgb + (1.0-last.a) * current.a * current.rgb;
    last.a   = last.a   + (1.0-last.a) * current.a;
    return last;
}

bool inBounds(float3 pos, RenderParams params) {
    return pos.x >= params.minBounds.x && pos.y >= params.minBounds.y && pos.z >= params.minBounds.z &&
    pos.x <= params.maxBounds.x && pos.y <= params.maxBounds.y && pos.z <= params.maxBounds.z;
}

v2f vertex vertexMain( uint vertexId [[vertex_id]],
                      device const float4* position [[buffer(0)]],
                      device const Matrices& matrices [[buffer(1)]])
{
    v2f o;
    o.position = matrices.modelViewProjection * position[ vertexId ];
    o.entryPoint = (matrices.clip*position[ vertexId ]).xyz+0.5;
    return o;
}

half4 fragment fragmentMain( v2f in [[stage_in]],
                            texture3d< half, access::sample > volume [[texture(0)]],
                            device const RenderParams& renderParams [[buffer(0)]])
{
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
        float4 current = transferFunction(volumeValue, renderParams);
        current.a = 1.0 - pow(1.0 - current.a, opacityCorrection);
        result = under(current, result);
        if (result.a > 0.95) break;
    } while (inBounds(currentPoint,renderParams));

    return half4( result );
}
