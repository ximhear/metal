//
//  Shaders.metal
//  TextTexture
//
//  Created by LEE CHUL HYUN on 7/4/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

// File for Metal kernel and shader functions

#include <metal_stdlib>
#include <simd/simd.h>

// Including header shared between this Metal shader code and Swift/C code executing Metal API commands
#import "ShaderTypes.h"

using namespace metal;

typedef struct
{
    float3 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float2 texCoord;
} ColorInOut;

typedef struct
{
    // The [[position]] attribute of this member indicates that this value is the clip space
    // position of the vertex when this structure is returned from the vertex function
    float4 clipSpacePosition [[position]];
    
    // Since this member does not have a special attribute, the rasterizer interpolates
    // its value with the values of the other triangle vertices and then passes
    // the interpolated value to the fragment shader for each fragment in the triangle
    float2 texCoords;
    
} RasterizerData;


// Vertex function
vertex RasterizerData
vertexShader(uint vertexID [[vertex_id]],
             constant AAPLVertex *vertices [[buffer(0)]],
             constant Uniforms &uniforms [[buffer(1)]])
{
    RasterizerData out;
    
    // Initialize our output clip space position
    out.clipSpacePosition = vector_float4(0.0, 0.0, 0.0, 1.0);
    
    // Index into our array of positions to get the current vertex
    //   Our positions are specified in pixel dimensions (i.e. a value of 100 is 100 pixels from
    //   the origin)
    float4 pixelSpacePosition = float4(vertices[vertexID].position.x, vertices[vertexID].position.y, 0, 1);
    
    // Dereference viewportSizePointer and cast to float so we can do floating-point division
    //    vector_float2 viewportSize = vector_float2(*viewportSizePointer);
    
    // The output position of every vertex shader is in clip-space (also known as normalized device
    //   coordinate space, or NDC).   A value of (-1.0, -1.0) in clip-space represents the
    //   lower-left corner of the viewport whereas (1.0, 1.0) represents the upper-right corner of
    //   the viewport.
    
    // Calculate and write x and y values to our clip-space position.  In order to convert from
    //   positions in pixel space to positions in clip-space, we divide the pixel coordinates by
    //   half the size of the viewport.
    float4 a = uniforms.projectionMatrix * uniforms.modelViewMatrix * pixelSpacePosition;
    out.clipSpacePosition.xy = float2(a.x, a.y);// / (viewportSize / 2.0);
    
    // Pass our input color straight to our output color.  This value will be interpolated
    //   with the other color values of the vertices that make up the triangle to produce
    //   the color value for each fragment in our fragment shader
    out.texCoords = vertices[vertexID].texCoords;
    
    return out;
}

// Fragment function
fragment half4 fragmentShader(RasterizerData vert [[stage_in]],
                              constant Uniforms &uniforms [[buffer(0)]],
                              sampler samplr [[sampler(0)]],
                              texture2d<float> texture [[texture(0)]])
{
    return half4(1, 0, 0, 1);
//    float4 color = uniforms.foregroundColor;
//    // Outline of glyph is the isocontour with value 50%
//    float edgeDistance = 0.5;
//    // Sample the signed-distance field to find distance from this fragment to the glyph outline
//    float sampleDistance = texture.sample(samplr, vert.texCoords).r;
//    float x = dfdx(sampleDistance);
//    float y = dfdy(sampleDistance);
//    float len = length(float2(x, y));
//    // Use local automatic gradients to find anti-aliased anisotropic edge width, cf. Gustavson 2012
//    float edgeWidth = 0.75 * len;
//    // Smooth the glyph edge by interpolating across the boundary in a band with the width determined above
//    float insideness = smoothstep(edgeDistance - edgeWidth, edgeDistance + edgeWidth, sampleDistance);
//    if (insideness == 0) {
//        return half4(1, 0, 0, 1);
//    }
//    return half4(color.r, color.g, color.b, insideness);
}


//vertex ColorInOut vertexShader(Vertex in [[stage_in]],
//                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
//{
//    ColorInOut out;
//
//    float4 position = float4(in.position, 1.0);
//    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
//    out.texCoord = in.texCoord;
//
//    return out;
//}
//
//fragment float4 fragmentShader(ColorInOut in [[stage_in]],
//                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
//                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
//{
//    constexpr sampler colorSampler(mip_filter::linear,
//                                   mag_filter::linear,
//                                   min_filter::linear);
//
//    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);
//
//    return float4(colorSample);
//}
