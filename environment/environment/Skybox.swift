//
//  Skybox.swift
//  environment
//
//  Created by LEE CHUL HYUN on 6/22/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal
import simd

class Skybox : Renderable {
    
    var device : MTLDevice
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var vertices: [MBEVertex]
    var indices: [UInt16]
    
    init(device: MTLDevice, indices: [UInt16], vertices: [MBEVertex]) {
        self.device = device
        self.vertices = vertices
        self.indices = indices
        self.makeBuffers()
    }
    
    func redraw(commandEncoder: MTLRenderCommandEncoder) -> Void {
        
        commandEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        
        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices.count, indexType: .uint16, indexBuffer: self.indexBuffer!, indexBufferOffset: 0)
        
    }
    
    func makeBuffers() {
        
        self.vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<MBEVertex>.stride, options: [])
        self.indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
    }
    
}
