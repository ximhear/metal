//
//  Renderer.swift
//  TextTexture
//
//  Created by LEE CHUL HYUN on 7/4/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size & ~0xFF) + 0x100

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var fontTexture: MTLTexture
    let maxCount = 10

    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    
    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    
    var atlasGenerator: FontAtlasGenerator
    
    var projectionMatrix: matrix_float4x4 = matrix_float4x4.init()
    var scaleMatrix: matrix_float4x4 = matrix_float4x4.init()
    
    var sampler: MTLSamplerState

    var vertexBuffer: MTLBuffer
    var indexBuffer: MTLBuffer

    init?(metalKitView: MTKView, atlasGenerator: FontAtlasGenerator) {
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        self.atlasGenerator = atlasGenerator
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)
        
        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            print("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDesciptor) else { return nil }
        depthState = state
        
        let samplerDescriptor = MTLSamplerDescriptor.init()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToZero
        samplerDescriptor.tAddressMode = .clampToZero
        guard let s = device.makeSamplerState(descriptor: samplerDescriptor) else {
            return nil
        }
        sampler = s

        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: atlasGenerator.textureWidth, height: atlasGenerator.textureHeight, mipmapped: false)
        textureDescriptor.usage = .shaderRead
        let region = MTLRegionMake2D(0, 0, atlasGenerator.textureWidth, atlasGenerator.textureHeight)
        
        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            return nil
        }
        fontTexture = texture
        fontTexture.label = "Text Texture"
        
        let minS: Float = 0
        let maxS: Float = 1
        let minT: Float = 0
        let maxT: Float = 1
        let a: Float = 1.0 / 1
        let valueX: Float = 0.95
        let valueY: Float = 0.95
        var triangleVertices = [AAPLVertex].init(repeating: AAPLVertex.init(), count: 4 * maxCount * maxCount)
        var triangleIndex = [UInt16].init(repeating: 0, count: 6 * maxCount * maxCount)
        let height = valueY * 2 / Float(maxCount)
        let fMaxCount = Float(maxCount)
        for row in 0..<maxCount {
            var width: Float = 0
            var width1: Float = 0
            
            var x: Float = 0
            var x1: Float = 0
            
            if a == 1 {
                width = valueX * 2 / fMaxCount
                width1 = valueX * 2 / fMaxCount
            }
            else {
                width = (2 * ((Float(row) * a * valueX) + (fMaxCount - Float(row)) * valueX) / fMaxCount) / fMaxCount
                width1 = (2 * ((Float(row + 1) * a * valueX) + (fMaxCount - Float(row) - 1) * valueX) / fMaxCount) / fMaxCount
            }
            
            x = -width * fMaxCount / 2.0;
            x1 = -width1 * fMaxCount / 2.0;
            
            for col in 0..<maxCount {
                
                var a0 = AAPLVertex()
                a0.position = vector_float2.init(x1 + width1 * Float(col + 1), valueY - height * Float(row + 1))
                a0.texCoords = vector_float2.init(maxS / fMaxCount * Float(col + 1), maxT / fMaxCount * Float(row + 1))
//                AAPLVertex a0 = { { x1 + width1 * (col + 1), valueY - height * (row+1)}, { maxS / maxCount * (col + 1), maxT / maxCount * (row+1)} };
                triangleVertices[row * maxCount * 4 + col * 4 + 0] = a0;
//
                var a1 = AAPLVertex()
                a1.position = vector_float2.init(x1 + width1 * Float(col + 0), valueY - height * Float(row + 1))
                a1.texCoords = vector_float2.init(maxS / fMaxCount * Float(col + 0), maxT / fMaxCount * Float(row + 1))
//                AAPLVertex a1 = { { x1 + width1 * (col + 0), valueY - height * (row+1)}, { maxS / maxCount * (col + 0), maxT / maxCount * (row+1)} };
                triangleVertices[row * maxCount * 4 + col * 4 + 1] = a1;
//
                var a2 = AAPLVertex()
                a2.position = vector_float2.init(x + width * Float(col + 0), valueY - height * Float(row+0))
                a2.texCoords = vector_float2.init(maxS / fMaxCount * Float(col + 0), maxT / fMaxCount * Float(row+0))
//                AAPLVertex a2 = { { x + width * (col + 0), valueY - height * (row+0)}, { maxS / maxCount * (col + 0), maxT / maxCount * (row+0)} };
                triangleVertices[row * maxCount * 4 + col * 4 + 2] = a2;
//
                var a3 = AAPLVertex()
                a3.position = vector_float2.init(x + width * Float(col + 1), valueY - height * Float(row + 0))
                a3.texCoords = vector_float2.init(maxS / fMaxCount * Float(col + 1), maxT / fMaxCount * Float(row + 0))
//                AAPLVertex a4 = { { x + width * (col + 1), valueY - height * (row+0)}, { maxS / maxCount * (col + 1), maxT / maxCount * (row+0)} };
                triangleVertices[row * maxCount * 4 + col * 4 + 3] = a3;
            }
        }
        
        for row in 0..<maxCount {
            for col in 0..<maxCount {
                triangleIndex[row * maxCount * 6 + col * 6 + 0] = UInt16(row * maxCount * 4 + col * 4 + 0)
                triangleIndex[row * maxCount * 6 + col * 6 + 1] = UInt16(row * maxCount * 4 + col * 4 + 1)
                triangleIndex[row * maxCount * 6 + col * 6 + 2] = UInt16(row * maxCount * 4 + col * 4 + 2)
                triangleIndex[row * maxCount * 6 + col * 6 + 3] = UInt16(row * maxCount * 4 + col * 4 + 2)
                triangleIndex[row * maxCount * 6 + col * 6 + 4] = UInt16(row * maxCount * 4 + col * 4 + 3)
                triangleIndex[row * maxCount * 6 + col * 6 + 5] = UInt16(row * maxCount * 4 + col * 4 + 0)
            }
        }
        
        guard let vb = device.makeBuffer(bytes: triangleVertices, length: triangleVertices.count * MemoryLayout<AAPLVertex>.stride, options: .cpuCacheModeWriteCombined) else {
            return nil
        }
        vertexBuffer = vb
        vertexBuffer.label = "Vertices"
        
        guard let ib = device.makeBuffer(bytes: triangleIndex, length: triangleIndex.count * MemoryLayout<UInt16>.stride, options: .cpuCacheModeWriteCombined) else {
            return nil
        }
        indexBuffer = ib
        indexBuffer.label = "Indices"
        
        super.init()
        
        _ = atlasGenerator.textureData?.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Int  in
            fontTexture.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: atlasGenerator.textureWidth)
            return 0
        })
    }
    
    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Creete a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
//        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
//        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
//        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
//        
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
//        
//        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
//        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
//        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
//        
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildRenderPipelineWithDevice(device: MTLDevice,
                                             metalKitView: MTKView,
                                             mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
//        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
    }

    private func updateGameState() {
        /// Update any game state before rendering
        
        uniforms[0].projectionMatrix = projectionMatrix
        uniforms[0].modelViewMatrix = scaleMatrix
        uniforms[0].foregroundColor = vector_float4.init(0, 1, 0, 1)
    }
    
    func draw(in view: MTKView) {
        /// Per frame updates hare
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            
            let semaphore = inFlightSemaphore
            commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
                semaphore.signal()
            }
            
            self.updateDynamicBufferState()
            
            self.updateGameState()
            
            /// Delay getting the currentRenderPassDescriptor until we absolutely need it to avoid
            ///   holding onto the drawable and blocking the display pipeline any longer than necessary
            let renderPassDescriptor = view.currentRenderPassDescriptor
            
            if let renderPassDescriptor = renderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                /// Final pass rendering code here
                renderEncoder.label = "Primary Render Encoder"
                
                renderEncoder.pushDebugGroup("Draw Box")
                
                renderEncoder.setCullMode(.back)
                
                renderEncoder.setFrontFacing(.clockwise)
                
                renderEncoder.setRenderPipelineState(pipelineState)
                
                renderEncoder.setDepthStencilState(depthState)
                
                renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
                renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: 1)
                renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: 0)
                renderEncoder.setFragmentTexture(self.fontTexture, index: 0)
                renderEncoder.setFragmentSamplerState(sampler, index: 0)

                renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 6 * maxCount * maxCount, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
//                [renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
//                    indexCount:[self.indexBuffer length] / sizeof(uint16_t)
//                    indexType:MTLIndexTypeUInt16
//                    indexBuffer:self.indexBuffer
//                    indexBufferOffset:0];

                
                renderEncoder.popDebugGroup()
                
                renderEncoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
            }
            
            commandBuffer.commit()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        let aspect1 = Float(size.height) / Float(size.width)

        var valueX: Float = 1
        var valueY: Float = 1
        
        if (aspect1 > 1) {
            valueY = valueX * aspect1;
        }
        else {
            valueX = valueY / aspect1;
        }
        
        
        var scale =  matrix_float4x4.init(diagonal: float4.init(1, 1, 1, 1))
        let aspect2 = Float(atlasGenerator.textureHeight) / Float(atlasGenerator.textureWidth)
        if (aspect2 > aspect1) {
            scale = matrix_float4x4(diagonal: float4(valueY / aspect2, valueY, 1, 1))
        }
        else {
            scale = matrix_float4x4(diagonal: float4(valueX, valueX * aspect2, 1, 1))
        }
        scaleMatrix = scale
        
        projectionMatrix = matrix_float4x4_ortho(left: -valueX, right: valueX, bottom: -valueY, top: valueY, near: -1, far: 1)
    }
}

// Generic matrix math utility functions
func matrix4x4_rotation(radians: Float, axis: float3) -> matrix_float4x4 {
    let unitAxis = normalize(axis)
    let ct = cosf(radians)
    let st = sinf(radians)
    let ci = 1 - ct
    let x = unitAxis.x, y = unitAxis.y, z = unitAxis.z
    return matrix_float4x4.init(columns:(vector_float4(    ct + x * x * ci, y * x * ci + z * st, z * x * ci - y * st, 0),
                                         vector_float4(x * y * ci - z * st,     ct + y * y * ci, z * y * ci + x * st, 0),
                                         vector_float4(x * z * ci + y * st, y * z * ci - x * st,     ct + z * z * ci, 0),
                                         vector_float4(                  0,                   0,                   0, 1)))
}

func matrix4x4_translation(_ translationX: Float, _ translationY: Float, _ translationZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(1, 0, 0, 0),
                                         vector_float4(0, 1, 0, 0),
                                         vector_float4(0, 0, 1, 0),
                                         vector_float4(translationX, translationY, translationZ, 1)))
}

func matrix_perspective_right_hand(fovyRadians fovy: Float, aspectRatio: Float, nearZ: Float, farZ: Float) -> matrix_float4x4 {
    let ys = 1 / tanf(fovy * 0.5)
    let xs = ys / aspectRatio
    let zs = farZ / (nearZ - farZ)
    return matrix_float4x4.init(columns:(vector_float4(xs,  0, 0,   0),
                                         vector_float4( 0, ys, 0,   0),
                                         vector_float4( 0,  0, zs, -1),
                                         vector_float4( 0,  0, zs * nearZ, 0)))
}

func radians_from_degrees(_ degrees: Float) -> Float {
    return (degrees / 180) * .pi
}

func matrix_float4x4_ortho(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> matrix_float4x4 {
    let ral = right + left
    let rsl = right - left
    let tab = top + bottom
    let tsb = top - bottom
    let fan = far + near
    let fsn = far - near
    
    let P = vector_float4( 2.0 / rsl, 0, 0, 0 )
    let Q = vector_float4( 0.0, 2.0 / tsb, 0.0, 0.0 )
    let R = vector_float4( 0.0, 0.0, -2.0 / fsn, 0.0 )
    let S = vector_float4( -ral / rsl, -tab / tsb, -fan / fsn, 1.0 )
    
    let mat = matrix_float4x4(columns:( P, Q, R, S ))
    return mat
}
