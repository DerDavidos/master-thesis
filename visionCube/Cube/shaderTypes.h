#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
typedef metal::int32_t EnumBackingType;
#else
#import <Foundation/Foundation.h>
typedef NSInteger EnumBackingType;
#endif

#include <simd/simd.h>

typedef NS_ENUM(EnumBackingType, BufferIndex)
{
    BufferIndexMeshPositions = 0,
    BufferIndexMeshGenerics  = 1,
    BufferIndexUniforms      = 2
};

typedef NS_ENUM(EnumBackingType, VertexAttribute)
{
    VertexAttributePosition  = 0,
    VertexAttributeTexcoord  = 1,
};

typedef NS_ENUM(EnumBackingType, TextureIndex)
{
    TextureIndexColor    = 0,
};

struct shaderMatrices {
    matrix_float4x4 modelViewProjection;
    matrix_float4x4 clip;
};

struct ShaderRenderParamaters {
    float smoothStepStart;
    float smoothStepShift;
    float oversampling;
    ushort xPos;
    ushort yPos;
    float cvScale;
    vector_float3 cameraPosInTextureSpace;
    vector_float3 minBounds;
    vector_float3 maxBounds;
    matrix_float4x4 modelView;
    matrix_float4x4 modelViewIT;
};

typedef struct
{
    struct shaderMatrices matrices[2];
} MatricesArray;

typedef struct
{
    struct ShaderRenderParamaters params[2];
} ParamsArray;
#endif /* ShaderTypes_h */

