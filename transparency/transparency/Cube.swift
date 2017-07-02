//
//  Cube.swift
//  transparency
//
//  Created by LEE CHUL HYUN on 7/3/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal
import simd

class Cube: Renderable {
    
    var device : MTLDevice
    let texture1: MTLTexture
    let texture2: MTLTexture
    var renderables = [Renderable]()
    var pipelineState : MTLRenderPipelineState?
    
    init(device: MTLDevice, texture1: MTLTexture, texture2: MTLTexture) {
        self.device = device
        self.texture1 = texture1
        self.texture2 = texture2
        makeCube()
        makePipelineState()
    }
    
    func makePipelineState() {
        
        let library = device.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertex_main")
        //        let fragmentFunc = library?.makeFunction(name: "fragment_main")
        let fragmentFunc = library?.makeFunction(name: "textured_fragment")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        
        self.pipelineState = try? self.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func makeCube() {
        
        var vertices1 = [
            MBEVertex(position: vector_float4(-1, 1, 1, 1), color: vector_float4(0, 1, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, -1, 1, 1), color: vector_float4(0, 0, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, -1, 1, 1), color: vector_float4(1, 0, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, 1, 1, 1), color: vector_float4(1, 1, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, 1, -1, 1), color: vector_float4(0, 1, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, -1, -1, 1), color: vector_float4(0, 0, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, -1, -1, 1), color: vector_float4(1, 0, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, 1, -1, 1), color: vector_float4(1, 1, 0, 1), texture:float2(0,0))
        ]
        
        var vertices : [MBEVertex] = []
        
        let indices2 : [(Int, Int, Int, Int)] = [
            (3, 2, 6, 7),
            (4, 5, 1, 0),
            (4, 0, 3, 7),
            (1, 5, 6, 2),
            (0, 1, 2, 3),
            (7, 6, 5, 4)
        ]
        
        for (index, (a, b, c, d)) in indices2.enumerated() {
            let vertex0 = vertices1[a]
            let vertex1 = vertices1[b]
            let vertex2 = vertices1[c]
            let vertex3 = vertices1[d]
            let rect = Rectangle(device: self.device, texture: index%2 == 0 ? self.texture1 : self.texture2, vertices: [vertex0, vertex1, vertex2, vertex3], makePipelineState: false)
            self.renderables.append(rect)
        }    }
    
    func redraw(commandEncoder: MTLRenderCommandEncoder) -> Void {
        
        commandEncoder.setRenderPipelineState(self.pipelineState!)
        for r in renderables {
            r.redraw(commandEncoder: commandEncoder)
        }
    }
}
