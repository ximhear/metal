//
//  ShaderTypes.h
//  TextTexture
//
//  Created by LEE CHUL HYUN on 7/4/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

//
//  Header containing types and enum constants shared between Metal shaders and Swift/ObjC source
//
#ifndef ShaderTypes_h
#define ShaderTypes_h

#ifdef __METAL_VERSION__
#define NS_ENUM(_type, _name) enum _name : _type _name; enum _name : _type
#define NSInteger metal::int32_t
#else
#import <Foundation/Foundation.h>
#endif

#include <simd/simd.h>

//typedef NS_ENUM(NSInteger, BufferIndex)
//{
//    BufferIndexMeshPositions = 0,
//    BufferIndexMeshGenerics  = 1,
//    BufferIndexUniforms      = 2
//};
//
//typedef NS_ENUM(NSInteger, VertexAttribute)
//{
//    VertexAttributePosition  = 0,
//    VertexAttributeTexcoord  = 1,
//};
//
//typedef NS_ENUM(NSInteger, TextureIndex)
//{
//    TextureIndexColor    = 0,
//};

typedef struct
{
    vector_float4 foregroundColor;
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} Uniforms;

//  This structure defines the layout of each vertex in the array of vertices set as an input to our
//    Metal vertex shader.  Since this header is shared between our .metal shader and C code,
//    we can be sure that the layout of the vertex array in our C code matches the layout that
//    our .metal vertex shader expects
typedef struct
{
    // Positions in pixel space
    // (e.g. a value of 100 indicates 100 pixels from the center)
    vector_float2 position;
    
    // Floating-point RGBA colors
    vector_float2 texCoords;
} AAPLVertex;

#endif /* ShaderTypes_h */

