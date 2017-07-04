//
//  Rectangle.swift
//  cube02
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
    
    init(device: MTLDevice, texture: MTLTexture, vertices: [MBEVertex]) {
        self.device = device
        self.texture = texture
        self.vertices = vertices
        makeBuffers()
    }
    
    func redraw(commandEncoder: MTLRenderCommandEncoder) -> Void {
        
        commandEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        commandEncoder.setFragmentTexture(self.texture, index: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: self.indexBuffer!.length / MemoryLayout<UInt16>.size, indexType: .uint16, indexBuffer: self.indexBuffer!, indexBufferOffset: 0, instanceCount: 125)
        
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
