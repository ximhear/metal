//
//  shaders.metal
//  environment
//
//  Created by LEE CHUL HYUN on 6/7/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[attribute(0)]];
    float4 normal [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 texture;
};

struct GMatrix {
    float4x4 matrix;
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
    float4x4 modelViewProjectionMatrix;
    float4x4 normalMatrix;
    float4 worldCameraPosition;
};

//vertex Vertex vertex_main(device Vertex* vertices[[buffer(0)]],
//                          constant Uniforms *uniforms[[buffer(1)]],
//                          uint vid[[vertex_id]]) {
//
//    Vertex out;
//    out.position = uniforms->modelViewProjectionMatrix * vertices[vid].position;
//    return out;
//}
//
//fragment half4 textured_fragment(Vertex vertexIn [[ stage_in ]],
//                                 sampler sampler2d [[ sampler(0) ]],
//                                 texture2d<float> texture [[ texture(0) ]] ) {
//    return half4(1,0,0,1);
////    float4 color = texture.sample(sampler2d, vertexIn.texture);
////    return half4(color.r, color.g, color.b, 1);
//}

vertex VertexOut vertex_skybox(device Vertex* vertices [[buffer(0)]],
                               constant Uniforms &uniforms [[buffer(1)]],
                                     uint vid[[vertex_id]])
{
    float4 position = vertices[vid].position;
    VertexOut outVertex;
    
    outVertex.position = uniforms.modelViewProjectionMatrix * position;
    outVertex.texture = position;
    return outVertex;
}

fragment half4 fragment_cube_lookup(VertexOut vertexIn [[stage_in]],
                                    texturecube<half> cubeTexture [[texture(0)]],
                                    sampler cubeSampler           [[sampler(0)]])
{
    float3 texCoords = float3(vertexIn.texture.x, vertexIn.texture.y, -vertexIn.texture.z);
    return cubeTexture.sample(cubeSampler, texCoords);
}
