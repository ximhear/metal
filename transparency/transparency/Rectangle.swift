//
//  Rectangle.swift
//  transparency
//
//  Created by LEE CHUL HYUN on 6/19/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal
import simd

class Rectangle : Renderable {
    
    var device : MTLDevice
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var texture: MTLTexture
    var vertices: [MBEVertex]
    var pipelineState : MTLRenderPipelineState?
    
    init(device: MTLDevice, texture: MTLTexture, vertices: [MBEVertex], makePipelineState: Bool) {
        self.device = device
        self.texture = texture
        self.vertices = vertices
        makeBuffers()
        if makePipelineState == true {
            self.makePipelineState()
        }
    }
    
    func makePipelineState() {
        
        let library = device.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertex_main1")
        let fragmentFunc = library?.makeFunction(name: "textured_fragment1")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        self.pipelineState = try? self.device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    func redraw(commandEncoder: MTLRenderCommandEncoder) -> Void {
        
        if let pipelineState = self.pipelineState {
            commandEncoder.setRenderPipelineState(pipelineState)
        }
        commandEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        commandEncoder.setFragmentTexture(self.texture, index: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: self.indexBuffer!.length / MemoryLayout<UInt16>.size, indexType: .uint16, indexBuffer: self.indexBuffer!, indexBufferOffset: 0)
        
    }
    
    func makeBuffers() {
        
        let indices : [UInt16] = [
            0, 1, 2, 2, 3, 0
        ]
        vertices[0].texture = float2(0,0)
        vertices[1].texture = float2(0,1)
        vertices[2].texture = float2(1,1)
        vertices[3].texture = float2(1,0)
        
        self.vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<MBEVertex>.stride, options: [])
        self.indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
    }
    
}
