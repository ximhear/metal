//
//  Shaders.metal
//  roulette
//
//  Created by LEE CHUL HYUN on 8/6/18.
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
    float3 position [[attribute(VertexAttributePosition)]];
    float2 texCoord [[attribute(VertexAttributeTexcoord)]];
} Vertex;

typedef struct
{
    float4 position [[position]];
    float4 orgPosition;
    float2 texCoord;
} ColorInOut;

vertex ColorInOut vertexShader(Vertex in [[ stage_in ]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;

    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.orgPosition = uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord.xy;

    return out;
}

vertex ColorInOut vertexShader1(Vertex in [[ stage_in ]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorInOut out;
    
    float4 position = float4(in.position, 1.0);
    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
    out.orgPosition = uniforms.modelViewMatrix * position;
    out.texCoord = in.texCoord.xy;
    
    return out;
}

//vertex ColorInOut vertexShader1(device Vertex* vertices [[ buffer(0) ]],
//                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
//                               uint vid[[vertex_id]])
//{
//    ColorInOut out;
//
//    float4 position = float4(vertices[vid].position, 1.0);
//    out.position = uniforms.projectionMatrix * uniforms.modelViewMatrix * position;
//    out.texCoord = vertices[vid].texCoord;
//
//    return out;
//}

fragment float4 fragmentShader(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);

    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);

    float len = length(in.orgPosition.xy);
    if (len > 1) {
        //        return half4(1,0,1,1);
        discard_fragment();
    }
    if (len > 0.99) {
        return float4(0,0,1,1);
    }
    return float4(colorSample);
}

fragment float4 fragmentShaderOffScreen(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    float len = length(in.orgPosition.xy);
    if (len > 1) {
        //        return half4(1,0,1,1);
        discard_fragment();
    }
    if (len > 0.99) {
        return float4(0,0,1,1);
    }
    return float4(1,0,1,1);
}


fragment float4 fragmentShader1(ColorInOut in [[stage_in]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                               texture2d<half> colorMap     [[ texture(TextureIndexColor) ]])
{
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    
    half4 colorSample   = colorMap.sample(colorSampler, in.texCoord.xy);
    
    //    return float4(1,0,0,1);
    return float4(colorSample);
}

fragment half4 signed_distance_field_fragment(ColorInOut vertexIn [[ stage_in ]],
                                              constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]],
                                 sampler sampler2d [[ sampler(0) ]],
                                 texture2d<float> texture [[ texture(TextureIndexColor) ]] ) {

    // Outline of glyph is the isocontour with value 50%
    float edgeDistance = 0.5;
    // Sample the signed-distance field to find distance from this fragment to the glyph outline
    float sampleDistance = texture.sample(sampler2d, vertexIn.texCoord).r;
    float x = dfdx(sampleDistance);
    float y = dfdy(sampleDistance);
    float len = length(float2(x, y));
    // Use local automatic gradients to find anti-aliased anisotropic edge width, cf. Gustavson 2012
    float edgeWidth = 0.75 * len;
    // Smooth the glyph edge by interpolating across the boundary in a band with the width determined above
    float insideness = smoothstep(edgeDistance - edgeWidth, edgeDistance + edgeWidth, sampleDistance);
    if (insideness == 0) {
        return half4(uniforms.bg.r, uniforms.bg.g, uniforms.bg.b, uniforms.bg.a);
    }
    return half4(uniforms.fg.r, uniforms.fg.g, uniforms.fg.b, 0) * insideness + half4(uniforms.bg.r * (1-insideness), uniforms.bg.g * (1-insideness), uniforms.bg.b * (1-insideness), uniforms.bg.a);
}
