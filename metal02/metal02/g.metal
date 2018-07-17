//
//  g.metal
//  metal02
//
//  Created by LEE CHUL HYUN on 4/22/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Vertex {
    float4 position [[position]];
    float4 color;
    float2 texture;
    float4 col0;
    float4 col1;
    float4 col2;
    float4 col3;
    int fragmentOption;
};

struct Uniforms {
    float4x4 modelViewProjectionMatrix;
};

vertex Vertex vertex_main(device Vertex* vertices[[buffer(0)]],
                          constant Uniforms *uniforms[[buffer(1)]],
                          uint vid[[vertex_id]]) {
    
    Vertex out;
    float4x4 mvp_matrix = float4x4(vertices[vid].col0, vertices[vid].col1, vertices[vid].col2, vertices[vid].col3);
    out.position = mvp_matrix * vertices[vid].position;
    out.color = vertices[vid].color;
    out.texture = vertices[vid].texture;
    out.fragmentOption = vertices[vid].fragmentOption;
    return out;
}

fragment float4 fragment_main(Vertex inVertex [[stage_in]]) {
    return inVertex.color;
}

fragment half4 textured_fragment(Vertex vertexIn [[ stage_in ]],
                                 sampler sampler2d [[ sampler(0) ]],
                                 texture2d<float> texture [[ texture(0) ]] ) {
    float4 color = texture.sample(sampler2d, vertexIn.texture);
    if (vertexIn.fragmentOption == -10) {
        // Outline of glyph is the isocontour with value 50%
        float edgeDistance = 0.5;
        // Sample the signed-distance field to find distance from this fragment to the glyph outline
        float sampleDistance = texture.sample(sampler2d, vertexIn.texture).r;
        float x = dfdx(sampleDistance);
        float y = dfdy(sampleDistance);
        float len = length(float2(x, y));
        // Use local automatic gradients to find anti-aliased anisotropic edge width, cf. Gustavson 2012
        float edgeWidth = 0.75 * len;
        // Smooth the glyph edge by interpolating across the boundary in a band with the width determined above
        float insideness = smoothstep(edgeDistance - edgeWidth, edgeDistance + edgeWidth, sampleDistance);
        if (insideness == 0) {
            return half4(1, 0, 0, 1);
        }
        return half4(0, 0, 1, insideness);
    }
    else {
        return half4(color.r, color.g, color.b, 1);
    }
}
