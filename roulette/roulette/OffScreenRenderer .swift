//
//  OffScreenRenderer.swift
//  roulette
//
//  Created by LEE CHUL HYUN on 8/6/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

class OffScreenRenderer: NSObject {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    
    var uniforms: UnsafeMutablePointer<Uniforms>

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var rotation: Float = 0
    
    var mesh: MTKMesh
    
    var samplerState: MTLSamplerState?
    
    var texture: MTLTexture?
    var outTexture: MTLTexture?
    var depthTexture : MTLTexture?

    init?(metalKitView: MTKView) {
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        let uniformBufferSize = alignedUniformsSize
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1

        let mtlVertexDescriptor = OffScreenRenderer.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try OffScreenRenderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            GZLog("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = .less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDesciptor) else { return nil }
        depthState = state
        
        do {
            mesh = try OffScreenRenderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            GZLog("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }


        super.init()
        
        buildSamplerState()
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Creete a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    func makeDepthTexture() {
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(500), height: Int(500), mipmapped: false)
        desc.usage = .renderTarget
        depthTexture = self.device.makeTexture(descriptor: desc)
    }

    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShaderOffScreen")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
//        pipelineDescriptor.stencilAttachmentPixelFormat = .stencil8
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.normalizedCoordinates = true
        samplerState = device.makeSamplerState(descriptor: descriptor)
        
    }


    class func buildMesh(device: MTLDevice,
                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate

        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let vertexBuffer1 = metalAllocator.newBuffer(8 * 3 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer
        let vertexBuffer2 = metalAllocator.newBuffer(8 * 2 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer

        let vertices = UnsafeMutableRawPointer(vertexBuffer1.buffer.contents()).bindMemory(to:Float.self, capacity: 8 * 3)
        var angle = Float.pi / 3.0
        
        var index: Int = 0
        vertices[index * 3 + 0] = 0
        vertices[index * 3 + 1] = 0
        vertices[index * 3 + 2] = 0

        index = 1
        vertices[index * 3 + 0] = 1
        vertices[index * 3 + 1] = 0
        vertices[index * 3 + 2] = 0

        index = 2
        angle = Float.pi / 3.0 * 1
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = 0

        index = 3
        angle = Float.pi / 3.0 * 2
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = 0

        index = 4
        angle = Float.pi / 3.0 * 3
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = 0

        index = 5
        angle = Float.pi / 3.0 * 4
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = 0

        index = 6
        angle = Float.pi / 3.0 * 5
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = 0

        index = 7
        vertices[index * 3 + 0] = 1
        vertices[index * 3 + 1] = 0
        vertices[index * 3 + 2] = 0

        for index in 0..<8 {
            vertices[index * 3 + 0] *= 1.25
            vertices[index * 3 + 1] *= 1.25
        }

        let vertices1 = UnsafeMutableRawPointer(vertexBuffer2.buffer.contents()).bindMemory(to:vector_float2.self, capacity: 8)
        vertices1[0] = vector_float2.init(0, 0)
        vertices1[1] = vector_float2.init(0, 1)
        vertices1[2] = vector_float2.init(1, 1)
        vertices1[3] = vector_float2.init(1, 0)
        vertices1[4] = vector_float2.init(1, 1)
        vertices1[5] = vector_float2.init(0, 1)
        vertices1[6] = vector_float2.init(1, 1)
        vertices1[7] = vector_float2.init(1, 0)

        let indexBuffer1 = metalAllocator.newBuffer(18 * MemoryLayout<UInt16>.stride, type: .index) as! MTKMeshBuffer
        let index1 = UnsafeMutableRawPointer(indexBuffer1.buffer.contents()).bindMemory(to:UInt16.self, capacity:18)
        index1[0] = 0
        index1[1] = 1
        index1[2] = 2
        index1[3] = 0
        index1[4] = 2
        index1[5] = 3
        index1[6] = 0
        index1[7] = 3
        index1[8] = 4
        index1[9] = 0
        index1[10] = 4
        index1[11] = 5
        index1[12] = 0
        index1[13] = 5
        index1[14] = 6
        index1[15] = 0
        index1[16] = 6
        index1[17] = 7

//        let indexBuffer2 = metalAllocator.newBuffer(3 * MemoryLayout<UInt16>.stride, type: .index) as! MTKMeshBuffer
//        let index2 = UnsafeMutableRawPointer(indexBuffer2.buffer.contents()).bindMemory(to:UInt16.self, capacity:3)
//        index2[0] = 0
//        index2[1] = 2
//        index2[2] = 3
        

        let submesh1 = MDLSubmesh.init(indexBuffer: indexBuffer1, indexCount: 18, indexType: .uInt16, geometryType: .triangles, material: nil)
//        let submesh2 = MDLSubmesh.init(indexBuffer: indexBuffer2, indexCount: 3, indexType: .uInt16, geometryType: .triangles, material: nil)
        let mdlMesh1 = MDLMesh.init(vertexBuffers: [vertexBuffer1, vertexBuffer2], vertexCount: 4, descriptor: mdlVertexDescriptor, submeshes: [submesh1])
        
        return try MTKMesh(mesh:mdlMesh1, device:device)
    }

    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + 0).bindMemory(to:Uniforms.self, capacity:1)
    }
    
    private func updateGameState() {
        /// Update any game state before rendering
        
        projectionMatrix = matrix_float4x4_ortho(left: -1, right: 1 , bottom: -1, top: 1, near: -5, far: 5)
        uniforms[0].projectionMatrix = projectionMatrix

        let rotationAxis = float3(0, 0, 1)
        let modelMatrix = matrix4x4_rotation(radians: Float.pi / 3.0, axis: rotationAxis)
        let viewMatrix = matrix4x4_translation(0.0, 0.0, -3.5)
        uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            self.updateDynamicBufferState()
            
            self.updateGameState()
            
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: 500, height: 500, mipmapped: false)
            textureDescriptor.usage = [.renderTarget, .shaderRead]
            
            self.texture = self.device.makeTexture(descriptor: textureDescriptor)

            let passDescriptor = MTLRenderPassDescriptor()
            passDescriptor.colorAttachments[0].texture = texture
            passDescriptor.colorAttachments[0].loadAction = .clear
            passDescriptor.colorAttachments[0].storeAction = .store
            passDescriptor.colorAttachments[0].clearColor = .init(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)

            makeDepthTexture()
            passDescriptor.depthAttachment.texture = self.depthTexture
            passDescriptor.depthAttachment.clearDepth = 1.0
            passDescriptor.depthAttachment.loadAction = .clear
            passDescriptor.depthAttachment.storeAction = .dontCare

            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = passDescriptor
            
            if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                /// Final pass rendering code here
                renderEncoder.label = "Primary Render Encoder"
                
                renderEncoder.pushDebugGroup("Draw Box")
                
                renderEncoder.setCullMode(.back)
                
                renderEncoder.setFrontFacing(.counterClockwise)
                
                renderEncoder.setRenderPipelineState(pipelineState)
                
                renderEncoder.setDepthStencilState(depthState)
                
                renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:0, index: BufferIndex.uniforms.rawValue)
                renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:0, index: BufferIndex.uniforms.rawValue)
                
                for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
                    guard let layout = element as? MDLVertexBufferLayout else {
                        return
                    }
                    
                    if layout.stride != 0 {
                        let buffer = mesh.vertexBuffers[index]
                        renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                    }
                }
                
                for submesh in mesh.submeshes {
                    renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                        indexCount: submesh.indexCount,
                                                        indexType: submesh.indexType,
                                                        indexBuffer: submesh.indexBuffer.buffer,
                                                        indexBufferOffset: submesh.indexBuffer.offset)
                    
                }
                
                renderEncoder.popDebugGroup()
                
                renderEncoder.endEncoding()
            }
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
    }
}
