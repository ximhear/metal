//
//  Cube.swift
//  cube02
//
//  Created by C.H Lee on 05/07/2017.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal
import simd

struct InstanceUniforms {
    var position : vector_float4
}

class Cube : Renderable {
    
    var device : MTLDevice
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var vertices: [MBEVertex]?
    var indices: [UInt16]?
    var width : Int
    var instanceUniforms : [InstanceUniforms]?
    
    init(device: MTLDevice, width: Int) {
        
        self.device = device
        self.width = width
        makeBuffers()
        instanceUniforms = createInstanceUniforms()
    }
    
    func makeBuffers() {
        
        self.vertices = [
            // + Y
            MBEVertex(position: vector_float4(-1.0,  1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0,  1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0,  1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(-1.0,  1.0, -1.0, 1.0)),
            // -Y
            MBEVertex(position: vector_float4(-1.0, -1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0, -1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0, -1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(-1.0, -1.0,  1.0, 1.0)),
            // +Z
            MBEVertex(position: vector_float4(-1.0, -1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0, -1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0,  1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(-1.0,  1.0,  1.0, 1.0)),
            // -Z
            MBEVertex(position: vector_float4(1.0, -1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(-1.0, -1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(-1.0,  1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0,  1.0, -1.0, 1.0)),
            // -X
            MBEVertex(position: vector_float4(-1.0, -1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(-1.0, -1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(-1.0,  1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(-1.0,  1.0, -1.0, 1.0)),
            // +X
            MBEVertex(position: vector_float4(1.0, -1.0,  1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0, -1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0,  1.0, -1.0, 1.0)),
            MBEVertex(position: vector_float4(1.0,  1.0,  1.0, 1.0)),
            ]
        
        self.indices = [
            0,  1,  2,  2,  3,  0,
            4,  5,  6,  6,  7,  4,
            8,  9, 10, 10, 11,  8,
            12, 13, 14, 14, 15, 12,
            16, 17, 18, 18, 19, 16,
            20, 21, 22, 22, 23, 20,
            ]
        
        self.vertexBuffer = device.makeBuffer(bytes: vertices!, length: vertices!.count * MemoryLayout<MBEVertex>.stride, options: [])
        self.indexBuffer = device.makeBuffer(bytes: indices!, length: indices!.count * MemoryLayout<UInt16>.size, options: [])
    }
    
    func redraw(commandEncoder: MTLRenderCommandEncoder) -> Void {
        
        commandEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBytes(self.instanceUniforms!, length: MemoryLayout<InstanceUniforms>.stride * self.instanceUniforms!.count, index: 2)

        commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: indices!.count, indexType: .uint16, indexBuffer: self.indexBuffer!, indexBufferOffset: 0,
                                             instanceCount: width * width * width)
        
    }
    
    func createInstanceUniforms() -> [InstanceUniforms] {
        
        var uniforms = [InstanceUniforms]()
        let ratio : Float = 3
        let offset = Float(self.width / 2)
        for x in 0..<self.width {
            for y in 0..<self.width {
                for z in 0..<self.width {
                    let u = InstanceUniforms(position: vector_float4(x: -ratio * offset + Float(x) * ratio, y: -ratio * offset + Float(y) * ratio, z: -ratio * offset + Float(z) * ratio, w: 1))
                    uniforms.append(u)
                }
            }
        }
        return uniforms
    }
}
