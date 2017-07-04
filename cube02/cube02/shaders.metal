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
    float4 color;
    float2 texture;
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
    float4x4 modelRotationMatrix;
};

struct InstanceUniforms {
    float4 position;
};

vertex Vertex vertex_main(device Vertex* vertices[[buffer(0)]],
                          constant Uniforms &uniforms [[buffer(1)]],
                          constant InstanceUniforms* instances [[buffer(2)]],
                          uint vid[[vertex_id]],
                          uint iid [[instance_id]]) {
    
    Vertex out;
    float4x4 translation = float4x4(1);
    translation[3][0] = instances[iid].position.x;
    translation[3][1] = instances[iid].position.y;
    translation[3][2] = instances[iid].position.z;
    
    out.position = uniforms.modelViewProjectionMatrix * translation * uniforms.modelRotationMatrix * vertices[vid].position;
    out.color = vertices[vid].color;
    out.texture = vertices[vid].texture;
    return out;
}

fragment float4 fragment_main(Vertex inVertex[[stage_in]]) {
    return inVertex.color;
}

fragment half4 textured_fragment(Vertex vertexIn [[ stage_in ]],
                                 sampler sampler2d [[ sampler(0) ]],
                                 texture2d<float> texture [[ texture(0) ]] ) {
    float4 color = texture.sample(sampler2d, vertexIn.texture);
    return half4(color.r, color.g, color.b, 1);
}
