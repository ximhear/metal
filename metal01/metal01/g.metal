//
//  g.metal
//  metal01
//
//  Created by LEE CHUL HYUN on 4/22/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;


struct Vertex {
    float4 position [[position]];
    float4 color;
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

vertex Vertex vertex_main(device Vertex* vertices[[buffer(0)]],
                          constant Uniforms *uniforms[[buffer(1)]],
                          uint vid[[vertex_id]]) {
    
    Vertex out;
    out.position = uniforms->modelViewProjectionMatrix * vertices[vid].position;
    out.color = vertices[vid].color;
    return out;
}

fragment float4 fragment_main(Vertex inVertex [[stage_in]]) {
    return inVertex.color;
}
