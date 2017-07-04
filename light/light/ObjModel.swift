//
//  ObjModel.swift
//  light
//
//  Created by C.H Lee on 30/06/2017.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal
import MetalKit
import simd

struct InstanceUniforms {
    var position : vector_float4
    var color : vector_float4
}

class ObjModel : Renderable {
    
    var meshes: [AnyObject]?
    var device : MTLDevice
    var instanceUniforms : [InstanceUniforms]?
    
    init(device: MTLDevice, objName: String) {
        self.device = device
        instanceUniforms = createInstanceUniforms()
        loadModel(device: device, modelName: objName)
    }
    
    var vertexDescriptor: MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .float4
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 7
        vertexDescriptor.attributes[2].bufferIndex = 0
        
        vertexDescriptor.attributes[3].format = .float3
        vertexDescriptor.attributes[3].offset = MemoryLayout<Float>.stride * 9
        vertexDescriptor.attributes[3].bufferIndex = 0
        
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 12
        
        return vertexDescriptor
    }

    func loadModel(device: MTLDevice, modelName: String) {
        guard let assetURL = Bundle.main.url(forResource: modelName, withExtension: "obj") else {
            fatalError("Asset \(modelName) does not exist.")
        }
        let descriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor)
        
        let attributePosition = descriptor.attributes[0] as! MDLVertexAttribute
        attributePosition.name = MDLVertexAttributePosition
        descriptor.attributes[0] = attributePosition
        
        let attributeColor = descriptor.attributes[1] as! MDLVertexAttribute
        attributeColor.name = MDLVertexAttributeColor
        descriptor.attributes[1] = attributeColor
        
        let attributeTexture = descriptor.attributes[2] as! MDLVertexAttribute
        attributeTexture.name = MDLVertexAttributeTextureCoordinate
        descriptor.attributes[2] = attributeTexture
        
        let attributeNormal = descriptor.attributes[3] as! MDLVertexAttribute
        attributeNormal.name = MDLVertexAttributeNormal
        descriptor.attributes[3] = attributeNormal
        
        let bufferAllocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: assetURL,
                             vertexDescriptor: descriptor,
                             bufferAllocator: bufferAllocator)
        
        do {
            meshes = try MTKMesh.newMeshes(from: asset,
                                           device: device,
                                           sourceMeshes: nil)
        } catch {
            print("mesh error")
        }
    }
    
    func redraw(commandEncoder: MTLRenderCommandEncoder) -> Void {
        
        guard let meshes = meshes as? [MTKMesh], meshes.count > 0 else { return }
        
        commandEncoder.setVertexBytes(self.instanceUniforms!, length: MemoryLayout<InstanceUniforms>.stride * self.instanceUniforms!.count, index: 2)
        
        for mesh in meshes {
            let vertexBuffer = mesh.vertexBuffers[0]
            commandEncoder.setVertexBuffer(vertexBuffer.buffer,
                                           offset: vertexBuffer.offset,
                                           index: 0)
            for submesh in mesh.submeshes {
                commandEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                     indexCount: submesh.indexCount,
                                                     indexType: submesh.indexType,
                                                     indexBuffer: submesh.indexBuffer.buffer,
                                                     indexBufferOffset: submesh.indexBuffer.offset,
                                                     instanceCount: 125)
            }
        }
    }
    
    func createInstanceUniforms() -> [InstanceUniforms] {
        
        var uniforms = [InstanceUniforms]()
        let ratio : Float = 1
        for x in 0..<5 {
            for y in 0..<5 {
                for z in 0..<5 {
                    let c = UIColor.getRandomColor()
                    var r : CGFloat = 0
                    var g : CGFloat = 0
                    var b : CGFloat = 0
                    var a : CGFloat = 0
                    c.getRed(&r, green: &g, blue: &b, alpha: &a)
                    let u = InstanceUniforms(position: vector_float4(x: -ratio * 2 + Float(x) * ratio, y: -ratio * 2 + Float(y) * ratio, z: -ratio * 2 + Float(z) * ratio, w: 1), color: vector_float4(x: Float(r), y: Float(g), z: Float(b), w: Float(a)))
                    uniforms.append(u)
                }
            }
        }
        return uniforms
    }
}
