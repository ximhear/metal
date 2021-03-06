//
//  shaders.metal
//  light
//
//  Created by LEE CHUL HYUN on 6/7/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Light
{
    float3 direction;
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
};

constant Light light = {
    .direction = { 0.13, 0.72, 0.68 },
    .ambientColor = { 0.05, 0.05, 0.05 },
    .diffuseColor = { 0.9, 0.9, 0.9 },
    .specularColor = { 1, 1, 1 }
};

struct Material
{
    float3 ambientColor;
    float3 diffuseColor;
    float3 specularColor;
    float specularPower;
};

constant Material material = {
    .ambientColor = { 0.9, 0.1, 0 },
    .diffuseColor = { 0.9, 0.1, 0 },
    .specularColor = { 1, 1, 1 },
    .specularPower = 100
};

struct Uniforms
{
    float4x4 modelViewProjectionMatrix;
    float4x4 modelViewMatrix;
    float3x3 normalMatrix;
};

struct Vertex
{
    float3 position [[attribute(0)]];
    float4 color [[attribute(1)]];
    float2 tex [[attribute(2)]];
    float3 normal [[attribute(3)]];
};

struct ProjectedVertex
{
    float4 position [[position]];
    float3 eye;
    float3 normal;
};

vertex ProjectedVertex vertex_project(const Vertex in [[stage_in]],
                                      constant Uniforms &uniforms [[buffer(1)]])
{
    ProjectedVertex outVert;
    float4 position = float4(in.position,1);
    outVert.position = uniforms.modelViewProjectionMatrix * position;
    outVert.eye =  -(uniforms.modelViewMatrix * position).xyz;
    outVert.normal = uniforms.normalMatrix * in.normal.xyz;
    
    return outVert;
}

fragment float4 fragment_light(ProjectedVertex vert [[stage_in]],
                               constant Uniforms &uniforms [[buffer(0)]])
{
    float3 ambientTerm = light.ambientColor * material.ambientColor;

    float3 normal = normalize(vert.normal);
    float diffuseIntensity = saturate(dot(normal, light.direction));
    float3 diffuseTerm = light.diffuseColor * material.diffuseColor * diffuseIntensity;

    float3 specularTerm(0);
    if (diffuseIntensity > 0)
    {
        float3 eyeDirection = normalize(vert.eye);
        float3 halfway = normalize(light.direction + eyeDirection);
        float specularFactor = pow(saturate(dot(normal, halfway)), material.specularPower);
        specularTerm = light.specularColor * material.specularColor * specularFactor;
    }

    return float4(ambientTerm + diffuseTerm + specularTerm, 1);
}
