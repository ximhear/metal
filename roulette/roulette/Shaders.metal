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
    float3 position [[attribute(0)]];
    float3 color [[attribute(1)]];
} ColorVertex;

typedef struct
{
    float4 position [[position]];
    float4 orgPosition;
    float4 rotPosition1;
    float4 rotPosition2;
    float4 color;
} ColorVertexInOut;

typedef struct
{
    float4 position [[position]];
    float4 orgPosition;
    float2 texCoord;
} ColorInOut;

struct ControlPoint {
    float4 position [[attribute(0)]];
};

vertex ColorVertexInOut coloredVertexShader(ColorVertex in [[ stage_in ]],
                               constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    ColorVertexInOut out;
    
    float4 position = float4(in.position, 1.0);
    out.orgPosition = uniforms.modelViewMatrix * position;
    out.rotPosition1 = uniforms.separatorRotationMatrix1 * position;
    out.rotPosition2 = uniforms.separatorRotationMatrix2 * position;
    float len = length(out.orgPosition.xy);
    float theta = -uniforms.speed * pow(len, 2);
//    if (theta M_PI_F
    float4x4 rotation = float4x4(float4(cos(theta), sin(theta), 0 ,0), float4(-sin(theta), cos(theta), 0 ,0), float4(0, 0, 1, 0), float4(0, 0, 0, 1));
    out.position = uniforms.projectionMatrix * rotation * uniforms.modelViewMatrix * position;
    out.color = float4(in.color, 1.0);
    
    return out;
}

fragment half4 fragmentShaderOffScreen(ColorVertexInOut in [[stage_in]],
                                        constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    float len = length(in.orgPosition.xy);
    if (len > 1) {
        //        return half4(1,0,1,1);
        discard_fragment();
    }
    if (len >= 0.98) {
        return half4(uniforms.lineColor);
    }
    return half4(in.color);
}

fragment half4 coloredFragmentShader(ColorVertexInOut in [[stage_in]],
                                       constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    if (in.rotPosition1.y > 1) {
        discard_fragment();
    }
    if (in.rotPosition2.y > 1) {
        discard_fragment();
    }
    return half4(in.color);
}

[[patch(quad, 4)]]
vertex ColorVertexInOut tessellationInstanceRenderingColoredVertexShader(patch_control_point<ControlPoint> control_points [[stage_in]],
                                                                         constant Uniforms* uniforms [[ buffer(BufferIndexUniforms) ]],
                                                                         float2 patch_coord [[position_in_patch]],
                                                                         ushort iid [[ instance_id ]])
{
    ColorVertexInOut out;
   
    float u = patch_coord.x;
    float v = patch_coord.y;

    float2 top = mix(control_points[0].position.xy,
                     control_points[1].position.xy, u);
    float2 bottom = mix(control_points[3].position.xy,
                        control_points[2].position.xy, u);


    float2 interpolated = mix(top, bottom, v);
    float4 position = float4(interpolated.x, interpolated.y, 0.0, 1.0);
    out.orgPosition = uniforms[iid].modelViewMatrix * position;
    out.rotPosition1 = uniforms[iid].separatorRotationMatrix1 * position;
    out.rotPosition2 = uniforms[iid].separatorRotationMatrix2 * position;

    float len = length(out.orgPosition.xy);
    float theta = -uniforms[iid].speed * pow(len, 2);
    float4x4 rotation = float4x4(float4(cos(theta), sin(theta), 0 ,0), float4(-sin(theta), cos(theta), 0 ,0), float4(0, 0, 1, 0), float4(0, 0, 0, 1));
    out.position = uniforms[iid].projectionMatrix * rotation * uniforms[iid].modelViewMatrix * position;
    out.color = float4(1, 1, 1, 0.35);
    
    return out;
}

[[patch(triangle, 3)]]
vertex ColorVertexInOut instanceRenderingColoredVertexShader(patch_control_point<ControlPoint> control_points [[stage_in]],
                                                                         constant Uniforms* uniforms [[ buffer(BufferIndexUniforms) ]],
                                                                         float3 patch_coord [[position_in_patch]],
                                                                         ushort iid [[ instance_id ]])
{
    ColorVertexInOut out;
    
    float u = patch_coord.x;
    float v = patch_coord.y;
    float w = patch_coord.z;
    float4 interpolated = control_points[0].position * u + control_points[1].position * v + control_points[2].position * w;
    float4 position = float4(interpolated.xyz, 1);
    out.orgPosition = uniforms[iid].modelViewMatrix * position;
    out.rotPosition1 = uniforms[iid].separatorRotationMatrix1 * position;
    out.rotPosition2 = uniforms[iid].separatorRotationMatrix2 * position;
    float len = length(out.orgPosition.xy);
    float theta = -uniforms[iid].speed * pow(len, 2);
    //    if (theta M_PI_F
    float4x4 rotation = float4x4(float4(cos(theta), sin(theta), 0 ,0), float4(-sin(theta), cos(theta), 0 ,0), float4(0, 0, 1, 0), float4(0, 0, 0, 1));
    out.position = uniforms[iid].projectionMatrix * rotation * uniforms[iid].modelViewMatrix * position;
    out.color = uniforms[iid].fg * float4(0.5 + u / 2.0, 0.5 + v / 2.0, 0.5 + w / 2.0, 1);
    
    return out;
}

fragment half4 instanceRenderingColoredFragmentShader(ColorVertexInOut in [[stage_in]],
                                     constant Uniforms & uniforms [[ buffer(BufferIndexUniforms) ]])
{
    if (in.rotPosition1.y > 1) {
        discard_fragment();
    }
    if (in.rotPosition2.y > 1) {
        discard_fragment();
    }
    return half4(in.color);
}



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

[[patch(quad, 4)]]
vertex ColorInOut vertexShader1(patch_control_point<ControlPoint> control_points [[stage_in]],
                               constant Uniforms& uniforms [[ buffer(BufferIndexUniforms) ]],
                                constant float4& rowVector [[ buffer(3) ]],
                                constant float4& colVector [[ buffer(4) ]],
                               float2 patch_coord [[position_in_patch]],
                                uint patch_id [[patch_id]],
                               ushort iid [[ instance_id ]])
{
    ColorInOut out;
    
    float u = patch_coord.x;
    float v = patch_coord.y;
    
    float3 top = mix(control_points[0].position.xyz,
                     control_points[1].position.xyz, u);
    float3 bottom = mix(control_points[3].position.xyz,
                        control_points[2].position.xyz, u);
    
    
    float3 interpolated = mix(top, bottom, v);
    float4 position = float4(interpolated.xyz, 1.0);
    out.orgPosition = uniforms.modelViewMatrix * position;
    float len = length(out.orgPosition.xy);
    float theta = -uniforms.speed * pow(len, 2);
    float4x4 rotation = float4x4(float4(cos(theta), sin(theta), 0 ,0), float4(-sin(theta), cos(theta), 0 ,0), float4(0, 0, 1, 0), float4(0, 0, 0, 1));
    out.position = uniforms.projectionMatrix * rotation * uniforms.modelViewMatrix * position;
    int row = rowVector.x;
    int col = colVector.x;
//    out.texCoord = float2(u, v);//float2(u / (float)col + (float)(patch_id % col) / (float)col, v / (float)row + (float)(patch_id / row) / (float)row);
    out.texCoord = float2(u / (float)col + (float)(patch_id % col) / (float)col, v / (float)row + (float)(row - (patch_id / col) - 1) / (float)row);

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
    return float4(colorSample);
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
                                 texture2d<half> texture [[ texture(TextureIndexColor) ]] ) {

    // Outline of glyph is the isocontour with value 50%
    half edgeDistance = 0.5;
    // Sample the signed-distance field to find distance from this fragment to the glyph outline
    half sampleDistance = texture.sample(sampler2d, vertexIn.texCoord).r;
    half x = dfdx(sampleDistance);
    half y = dfdy(sampleDistance);
    half len = length(half2(x, y));
    // Use local automatic gradients to find anti-aliased anisotropic edge width, cf. Gustavson 2012
    half edgeWidth = 0.75 * len;
    // Smooth the glyph edge by interpolating across the boundary in a band with the width determined above
    half insideness = smoothstep(edgeDistance - edgeWidth, edgeDistance + edgeWidth, sampleDistance);
    if (insideness == 0) {
//        return half4(0, 1, 0, 1);
		discard_fragment();
//        return half4(uniforms.bg.r, uniforms.bg.g, uniforms.bg.b, uniforms.bg.a);
    }
//    return half4(1, 0, 0, 1);
    return half4(uniforms.fg.r, uniforms.fg.g, uniforms.fg.b, 0) * insideness + half4(uniforms.bg.r * (1-insideness), uniforms.bg.g * (1-insideness), uniforms.bg.b * (1-insideness), uniforms.bg.a);
}

kernel void tessellation_main(constant float* edge_factors [[buffer(0)]],
               constant float* inside_factors [[buffer(1)]],
               device MTLQuadTessellationFactorsHalf*
                              factors [[buffer(2)]],
               uint pid [[thread_position_in_grid]]) {
      
      
      factors[pid].edgeTessellationFactor[0] = edge_factors[0];
      factors[pid].edgeTessellationFactor[1] = edge_factors[0];
      factors[pid].edgeTessellationFactor[2] = edge_factors[0];
      factors[pid].edgeTessellationFactor[3] = edge_factors[0];
        
      factors[pid].insideTessellationFactor[0] = inside_factors[0];
      factors[pid].insideTessellationFactor[1] = inside_factors[0];

}

kernel void tessellation_triangle_main(constant float* edge_factors [[ buffer(0) ]],
                              constant float& inside_factors [[ buffer(1) ]],
                              device MTLTriangleTessellationFactorsHalf* factors [[buffer(2)]],
                              uint pid [[thread_position_in_grid]]) {
    
    factors[pid].edgeTessellationFactor[0] = edge_factors[0];
    factors[pid].edgeTessellationFactor[1] = edge_factors[1];
    factors[pid].edgeTessellationFactor[2] = edge_factors[2];

    factors[pid].insideTessellationFactor = inside_factors;
}
