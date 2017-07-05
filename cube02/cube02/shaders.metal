//
//  shaders.metal
//  cube02
//
//  Created by LEE CHUL HYUN on 6/7/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
};

struct VertexOut {
    float4 position [[position]];
    float4 texture;
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelRotationMatrix;
};

struct InstanceUniforms {
    float4 position;
};

vertex VertexOut vertex_main(device Vertex* vertices[[buffer(0)]],
                          constant Uniforms &uniforms [[buffer(1)]],
                          constant InstanceUniforms* instances [[buffer(2)]],
                          uint vid[[vertex_id]],
                          uint iid [[instance_id]]) {
    
    VertexOut outVertex;
    float4x4 translation = float4x4(1);
    float4 transPosition = instances[iid].position;
    translation[3][0] = transPosition.x;
    translation[3][1] = transPosition.y;
    translation[3][2] = transPosition.z;
    
    float4 position = vertices[vid].position;
    outVertex.position = uniforms.modelViewProjectionMatrix * translation * uniforms.modelRotationMatrix * position;
    outVertex.texture = position;
    return outVertex;
}

fragment half4 fragment_cube_lookup(VertexOut vertexIn [[stage_in]],
                                    texturecube<half> cubeTexture [[texture(0)]],
                                    sampler cubeSampler           [[sampler(0)]])
{
    float3 texCoords = float3(vertexIn.texture.x, vertexIn.texture.y, vertexIn.texture.z);
    return cubeTexture.sample(cubeSampler, texCoords);
}
