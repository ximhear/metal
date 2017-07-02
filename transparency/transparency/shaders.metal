//
//  shaders.metal
//  transparency
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
};

vertex Vertex vertex_main1(device Vertex* vertices[[buffer(0)]],
                          constant Uniforms *uniforms[[buffer(1)]],
                          uint vid[[vertex_id]]) {
    
    Vertex out;
    out.position = vertices[vid].position;
    out.color = vertices[vid].color;
    out.texture = vertices[vid].texture;
    return out;
}

vertex Vertex vertex_main(device Vertex* vertices[[buffer(0)]],
                          constant Uniforms *uniforms[[buffer(1)]],
                          uint vid[[vertex_id]]) {
    
    Vertex out;
    out.position = uniforms->modelViewProjectionMatrix * vertices[vid].position;
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

fragment half4 textured_fragment1(Vertex vertexIn [[ stage_in ]],
                                 sampler sampler2d [[ sampler(0) ]],
                                 texture2d<float> texture [[ texture(0) ]] ) {
    float4 color = texture.sample(sampler2d, vertexIn.texture);
    
    if (color.r == 1.0 && color.g == 1.0 && color.b == 1.0 && color.a == 1.0) {
        discard_fragment();
    }
//    if (color.r == 1.0 && color.g == 1.0 && color.b == 0.0 && color.a == 1.0) {
//        return half4(color.r, color.g, color.b, 0.5);
//    }
//    if (color.r == 0.0 && color.g == 1.0 && color.b == 0.0 && color.a == 1.0) {
//        return half4(color.r, color.g, color.b, 0.75);
//    }
//    if (color.r == 0.0 && color.g == 0.0 && color.b == 1.0 && color.a == 1.0) {
//        return half4(color.r, color.g, color.b, 0.25);
//    }
//    if (color.r == 1.0 && color.g == 0.0 && color.b == 0.0 && color.a == 1.0) {
//        return half4(color.r, color.g, color.b, 0.5);
//    }
    return half4(color.r, color.g, color.b, 0.5);
}
