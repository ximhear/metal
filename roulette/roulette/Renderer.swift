//
//  Renderer.swift
//  roulette
//
//  Created by LEE CHUL HYUN on 8/6/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

// Our platform independent renderer class

import Metal
import MetalKit
import simd

struct GVertex {
    var position: vector_float3 = vector_float3()
    var texCoord: vector_float2 = vector_float2()
}

// The 256 byte aligned size of our uniform structure
let alignedUniformsSize = (MemoryLayout<Uniforms>.size & ~0xFF) + 0x100
let aligned6UniformsSize = ((MemoryLayout<Uniforms>.size * 6) & ~0xFF) + 0x100
let uniformsSize = MemoryLayout<Uniforms>.size

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var dynamicUniformBuffer1: MTLBuffer
    var dynamicUniformBuffer2: MTLBuffer
    var pipelineState: MTLRenderPipelineState
    var pipelineState1: MTLRenderPipelineState
    var pipelineState2: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var colorMap: MTLTexture
    var illuminati: MTLTexture
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    var sixUniformBufferOffset = 0

    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    var uniforms1: UnsafeMutablePointer<Uniforms>
    var uniforms2: UnsafeMutablePointer<Uniforms>

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var texture1Width: Float = 0
    var texture2Width: Float = 0
    
    var scale1X: Float = 1
    var scale1Y: Float = 1
    
    var scale2X: Float = 1
    var scale2Y: Float = 1

    var mesh: MTKMesh
    var mesh1: MTKMesh
    var mesh2: MTKMesh
    
    var atlasGenerator1: FontAtlasGenerator?
    var atlasGenerator2: FontAtlasGenerator?
    var fontTexture1: MTLTexture?
    var fontTexture2: MTLTexture?
    var samplerState: MTLSamplerState?
    var sampler: MTLSamplerState?
    
    var timingFunction: ((_ tx: Double) -> Double)?
    var beginingTime: Double = 0
    var endingTime: Double = 0
    var rotating = false
    var beginingRotationZ: Double = 0
    var endingRotationZ: Double = 0
    var elapsedTime : Double = 0
    var rotationZ : Double = 0

    init?(metalKitView: MTKView, t: MTLTexture) {
        self.device = metalKitView.device!
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

        guard let buffer1 = self.device.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer1 = buffer1
        
        self.dynamicUniformBuffer1.label = "UniformBuffer1"
        
        uniforms1 = UnsafeMutableRawPointer(dynamicUniformBuffer1.contents()).bindMemory(to:Uniforms.self, capacity:1)

        let uniformBufferSize2 = aligned6UniformsSize * maxBuffersInFlight
        guard let buffer2 = self.device.makeBuffer(length:uniformBufferSize2, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        dynamicUniformBuffer2 = buffer2
        
        self.dynamicUniformBuffer2.label = "UniformBuffer2"
        
        uniforms2 = UnsafeMutableRawPointer(dynamicUniformBuffer2.contents()).bindMemory(to:Uniforms.self, capacity: 6)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
        do {
            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            GZLog("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        do {
            pipelineState1 = try Renderer.buildRenderPipelineWithDevice1(device: device,
                                                                       metalKitView: metalKitView,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            GZLog("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        do {
            pipelineState2 = try Renderer.buildRenderPipelineWithDevice2(device: device,
                                                                         metalKitView: metalKitView,
                                                                         mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            GZLog("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let depthStateDesciptor = MTLDepthStencilDescriptor()
        depthStateDesciptor.depthCompareFunction = MTLCompareFunction.less
        depthStateDesciptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor:depthStateDesciptor) else { return nil }
        depthState = state
        
        do {
            mesh = try Renderer.buildMesh(device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            GZLog("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }

        do {
            mesh1 = try Renderer.buildMesh1 (device: device, mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            GZLog("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }

//        do {
//            colorMap = try Renderer.loadTexture(device: device, textureName: "ColorMap")
//        } catch {
//            GZLog("Unable to load texture. Error info: \(error)")
//            return nil
//        }
        
        colorMap = t
        illuminati = t
//        do {
//            illuminati = try Renderer.loadTexture(device: device, texture: t)
////            illuminati = try Renderer.loadTexture(device: device, textureName: "illuminati")
//        } catch {
//            GZLog("Unable to load texture. Error info: \(error)")
//            return nil
//        }

        do {
            mesh2 = try Renderer.buildMesh2 (device: device, mtlVertexDescriptor: mtlVertexDescriptor, ratio: 1, divideCount: 1)
        } catch {
            GZLog("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }
        
        let font1 = UIFont.systemFont(ofSize: 128)
        atlasGenerator1 = FontAtlasGenerator.init()
        atlasGenerator1!.createTextureData(font: font1, string: "Pandas")

        let font2 = UIFont.init(name: "AppleSDGothicNeo-Regular", size: 128)
        atlasGenerator2 = FontAtlasGenerator.init()
        atlasGenerator2!.createTextureData(font: font2!, string: "커피")
        
        var x1: Float = 0
        var x2: Float = 0
        var p: Float = 1
        var t: Float = 1
        
        p = Float(atlasGenerator1!.textureHeight) / Float(atlasGenerator1!.textureWidth)
        t = tan(Float.pi / 2.0 - Float.pi / 6.0)
        
        x1 = (-p + sqrt(4 * p * p + 3)) / 2 / (p * p + 1)
        x2 = 0.5 / (t + p)
        scale1X = min(x1, x2) * 2
        scale1Y = scale1X * p

        p = Float(atlasGenerator2!.textureHeight) / Float(atlasGenerator2!.textureWidth)
        
        x1 = (-p + sqrt(4 * p * p + 3)) / 2 / (p * p + 1)
        x2 = 0.5 / (t + p)
        scale2X = min(x1, x2) * 2
        scale2Y = scale2X * p

        let textureDescriptor1 = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: atlasGenerator1!.textureWidth, height: atlasGenerator1!.textureHeight, mipmapped: false)
        textureDescriptor1.usage = .shaderRead
        let region1 = MTLRegionMake2D(0, 0, atlasGenerator1!.textureWidth, atlasGenerator1!.textureHeight)

        let textureDescriptor2 = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: atlasGenerator2!.textureWidth, height: atlasGenerator2!.textureHeight, mipmapped: false)
        textureDescriptor2.usage = .shaderRead
        let region2 = MTLRegionMake2D(0, 0, atlasGenerator2!.textureWidth, atlasGenerator2!.textureHeight)

        fontTexture1 = device.makeTexture(descriptor: textureDescriptor1)
        fontTexture2 = device.makeTexture(descriptor: textureDescriptor2)

        super.init()
        
        _ = atlasGenerator1!.textureData?.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Int  in
            fontTexture1?.replace(region: region1, mipmapLevel: 0, withBytes: bytes, bytesPerRow: atlasGenerator1!.textureWidth)
            return 0
        })

        _ = atlasGenerator2!.textureData?.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Int  in
            fontTexture2?.replace(region: region2, mipmapLevel: 0, withBytes: bytes, bytesPerRow: atlasGenerator2!.textureWidth)
            return 0
        })

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
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildRenderPipelineWithDevice1(device: MTLDevice,
                                              metalKitView: MTKView,
                                              mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader1")
        let fragmentFunction = library?.makeFunction(name: "fragmentShader1")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline1"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    class func buildRenderPipelineWithDevice2(device: MTLDevice,
                                              metalKitView: MTKView,
                                              mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "vertexShader1")
        let fragmentFunction = library?.makeFunction(name: "signed_distance_field_fragment")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.label = "RenderPipeline1"
        pipelineDescriptor.sampleCount = metalKitView.sampleCount
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        pipelineDescriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        pipelineDescriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        pipelineDescriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.normalizedCoordinates = true
        samplerState = device.makeSamplerState(descriptor: descriptor)
        
        let samplerDescriptor = MTLSamplerDescriptor.init()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.sAddressMode = .clampToZero
        samplerDescriptor.tAddressMode = .clampToZero
        sampler = device.makeSamplerState(descriptor: samplerDescriptor)
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
        
        let vertexBuffer1 = metalAllocator.newBuffer(4 * 3 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer
        let vertexBuffer2 = metalAllocator.newBuffer(4 * 2 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer

        let vertices = UnsafeMutableRawPointer(vertexBuffer1.buffer.contents()).bindMemory(to:Float.self, capacity: 8 * 3)
        var angle = Float.pi / 3.0
        
        var index: Int = 0
        vertices[index * 3 + 0] = -1
        vertices[index * 3 + 1] = 1
        vertices[index * 3 + 2] = 0

        index = 1
        vertices[index * 3 + 0] = -1
        vertices[index * 3 + 1] = -1
        vertices[index * 3 + 2] = 0

        index = 2
        vertices[index * 3 + 0] = 1
        vertices[index * 3 + 1] = -1
        vertices[index * 3 + 2] = 0

        index = 3
        vertices[index * 3 + 0] = 1
        vertices[index * 3 + 1] = 1
        vertices[index * 3 + 2] = 0

        let vertices1 = UnsafeMutableRawPointer(vertexBuffer2.buffer.contents()).bindMemory(to:vector_float2.self, capacity: 8)
        vertices1[0] = vector_float2.init(0, 0)
        vertices1[1] = vector_float2.init(0, 1)
        vertices1[2] = vector_float2.init(1, 1)
        vertices1[3] = vector_float2.init(1, 0)

        let indexBuffer1 = metalAllocator.newBuffer(6 * MemoryLayout<UInt16>.stride, type: .index) as! MTKMeshBuffer
        let index1 = UnsafeMutableRawPointer(indexBuffer1.buffer.contents()).bindMemory(to:UInt16.self, capacity:18)
        index1[0] = 0
        index1[1] = 1
        index1[2] = 2
        index1[3] = 0
        index1[4] = 2
        index1[5] = 3

        let submesh1 = MDLSubmesh.init(indexBuffer: indexBuffer1, indexCount: 6, indexType: .uInt16, geometryType: .triangles, material: nil)
        let mdlMesh1 = MDLMesh.init(vertexBuffers: [vertexBuffer1, vertexBuffer2], vertexCount: 4, descriptor: mdlVertexDescriptor, submeshes: [submesh1])
        
        return try MTKMesh(mesh:mdlMesh1, device:device)
    }

    class func buildMesh1(device: MTLDevice,
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
        let startAngle = Float.pi / 3.0 / 2.0
        let z: Float = 0

        var index: Int = 0
        vertices[index * 3 + 0] = 0
        vertices[index * 3 + 1] = 0
        vertices[index * 3 + 2] = z
        
        index = 1
        angle = startAngle + Float.pi / 3.0 * Float(index - 1)
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = z

        index = 2
        angle = startAngle + Float.pi / 3.0 * Float(index - 1)
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = z

        index = 3
        angle = startAngle + Float.pi / 3.0 * Float(index - 1)
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = z

        index = 4
        angle = startAngle + Float.pi / 3.0 * Float(index - 1)
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = z

        index = 5
        angle = startAngle + Float.pi / 3.0 * Float(index - 1)
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = z

        index = 6
        angle = startAngle + Float.pi / 3.0 * Float(index - 1)
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = z

        index = 7
        angle = startAngle + Float.pi / 3.0 * Float(index - 1)
        vertices[index * 3 + 0] = cos(angle)
        vertices[index * 3 + 1] = sin(angle)
        vertices[index * 3 + 2] = z
        
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
    
    class func buildMesh2(device: MTLDevice, mtlVertexDescriptor: MTLVertexDescriptor, ratio: Float, divideCount: Int) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        let maxCount: Int = divideCount
        let maxPlusOneCount: Int = maxCount + 1
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeTextureCoordinate
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let vertexBuffer1 = metalAllocator.newBuffer(maxPlusOneCount * maxPlusOneCount * 3 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer
        let vertexBuffer2 = metalAllocator.newBuffer(maxPlusOneCount * maxPlusOneCount * 2 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer
        
        let vertices = UnsafeMutableRawPointer(vertexBuffer1.buffer.contents()).bindMemory(to:Float.self, capacity: maxPlusOneCount * maxPlusOneCount * 3)
        let vertices1 = UnsafeMutableRawPointer(vertexBuffer2.buffer.contents()).bindMemory(to:vector_float2.self, capacity: maxPlusOneCount * maxPlusOneCount)
        
        let indexBuffer1 = metalAllocator.newBuffer(maxCount * maxCount * 6 * MemoryLayout<UInt16>.stride, type: .index) as! MTKMeshBuffer
        let index1 = UnsafeMutableRawPointer(indexBuffer1.buffer.contents()).bindMemory(to:UInt16.self, capacity: maxCount * maxCount * 6)
        
        let z: Float = 0

        let fMaxCount = Float(maxCount)
        let height: Float = 1.0 / fMaxCount
        for row in 0...maxCount {
            var width: Float = 0
            
            var x: Float = 0
            
            if ratio == 1 {
                width = 1 / fMaxCount
            }
            else {
                width = (1 * (fMaxCount - Float(row)) + ratio * Float(row)) / fMaxCount / fMaxCount
            }
            
            x = -width * fMaxCount / 2.0
            
            for col in 0...maxCount {
                
                let position0 = vector_float3.init(x + width * Float(col), 1 - height * Float(row), z)
                vertices[row * maxPlusOneCount * 3 + col * 3 + 0] = position0.x
                vertices[row * maxPlusOneCount * 3 + col * 3 + 1] = position0.y
                vertices[row * maxPlusOneCount * 3 + col * 3 + 2] = position0.z
                
                let texture0 = vector_float2.init(1 / fMaxCount * Float(col), 1 / fMaxCount * Float(row))
                vertices1[row * maxPlusOneCount + col] = texture0
            }
        }

        for row in 0...maxCount {
            for col in 0...maxCount {
                index1[row * maxCount * 6 + col * 6 + 0] = UInt16((row + 0) * maxPlusOneCount + col)
                index1[row * maxCount * 6 + col * 6 + 1] = UInt16((row + 1) * maxPlusOneCount + col)
                index1[row * maxCount * 6 + col * 6 + 2] = UInt16((row + 1) * maxPlusOneCount + col + 1)
                index1[row * maxCount * 6 + col * 6 + 3] = UInt16((row + 0) * maxPlusOneCount + col)
                index1[row * maxCount * 6 + col * 6 + 4] = UInt16((row + 1) * maxPlusOneCount + col + 1)
                index1[row * maxCount * 6 + col * 6 + 5] = UInt16((row + 0) * maxPlusOneCount + col + 1)
            }
        }

        let submesh1 = MDLSubmesh.init(indexBuffer: indexBuffer1, indexCount: maxCount * maxCount * 6, indexType: .uInt16, geometryType: .triangles, material: nil)
        let mdlMesh1 = MDLMesh.init(vertexBuffers: [vertexBuffer1, vertexBuffer2], vertexCount: maxPlusOneCount * maxPlusOneCount, descriptor: mdlVertexDescriptor, submeshes: [submesh1])
        
        return try MTKMesh(mesh:mdlMesh1, device:device)
    }
    
    class func loadTexture(device: MTLDevice,
                           textureName: String) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]
        
        return try textureLoader.newTexture(name: textureName,
                                            scaleFactor: 1.0,
                                            bundle: nil,
                                            options: textureLoaderOptions)
        
    }
    
    class func loadTexture(device: MTLDevice,
                           texture: MTLTexture) throws -> MTLTexture {
        /// Load texture data with optimal parameters for sampling
        
        let textureLoader = MTKTextureLoader(device: device)
        
        let textureLoaderOptions = [
            MTKTextureLoader.Option.textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            MTKTextureLoader.Option.textureStorageMode: NSNumber(value: MTLStorageMode.`private`.rawValue)
        ]

        let imageByteCount = texture.width * texture.height * 4
        
        // An empty buffer that will contain the image
        var src = [UInt8](repeating: 0, count: Int(imageByteCount))
        texture.getBytes(&src, bytesPerRow: texture.width * 4, from: MTLRegionMake2D(0, 0, 500, 500), mipmapLevel: 0)
        let data = Data.init(bytes: src, count: src.count)
        return try textureLoader.newTexture(data: data, options: textureLoaderOptions)
    }

    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        uniforms1 = UnsafeMutableRawPointer(dynamicUniformBuffer1.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)
        
        sixUniformBufferOffset = aligned6UniformsSize * uniformBufferIndex
        uniforms2 = UnsafeMutableRawPointer(dynamicUniformBuffer2.contents() + sixUniformBufferOffset).bindMemory(to:Uniforms.self, capacity: 6)
    }
    
    private func updateGameState() {
        /// Update any game state before rendering
        
        uniforms[0].projectionMatrix = projectionMatrix
        
        
        if self.rotating == true {
            elapsedTime = Date().timeIntervalSince1970 - self.beginingTime
            
            if self.beginingTime + elapsedTime >= self.endingTime {
                self.rotationZ = self.endingRotationZ
                self.rotating = false
                GZLog("Rotation ended")
            }
            else {
                var result: Double = 0
                if let timingFunction = self.timingFunction {
                    result = beginingRotationZ + timingFunction(elapsedTime/(self.endingTime - self.beginingTime)) * (self.endingRotationZ - beginingRotationZ)
                }
                else {
                    result = beginingRotationZ + (self.endingRotationZ - beginingRotationZ) * elapsedTime / (self.endingTime - self.beginingTime)
                }
                self.rotationZ = result
            }
        }

        let rotationAxis = float3(0, 0, 1)
        let modelMatrix = matrix4x4_rotation(radians: Float(self.rotationZ), axis: rotationAxis)
        let viewMatrix = matrix4x4_translation(0.0, 0.0, -3.5)
        uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        
        let rotationAxis2 = float3(0, 0, 1)
        let viewMatrix2 = matrix4x4_translation(0.0, 0.0, -3.2)
        
        let radius: Float = 1
        let theta = Float.pi / 3.0
        let ratio: Float = 1.0 / 10.0
        let moveY = radius * cos(theta / 2.0) * ratio
        let scaleX = radius * sin(theta / 2.0) * 2
        let scaleY = radius * cos(theta / 2.0) - moveY
        let scaleZ: Float = 1
        
        let scaleMatrix = matrix4x4_scale(scaleX, scaleY, scaleZ)
        let transitionY = matrix4x4_translation(0, moveY, 0)
        
        let transition1Y = matrix4x4_translation(0, -0.5, 0)
        let transition2Y = matrix4x4_translation(0, 0.5, 0)

        let scaleMatrix1 = matrix4x4_scale(scale1X, scale1Y, 1)
        let scaleMatrix2 = matrix4x4_scale(scale2X, scale2Y, 1)

        let fgs = [simd_float4(1, 0, 0, 1), simd_float4(0, 1, 0, 1), simd_float4(0, 0, 1, 1), simd_float4(1, 1, 0, 1), simd_float4(1, 0, 1, 1), simd_float4(0, 1, 1, 1)]
        let bgs = [simd_float4(0, 1, 1, 1), simd_float4(1, 0, 1, 1), simd_float4(1, 1, 0, 1), simd_float4(0, 0, 1, 1), simd_float4(0, 1, 0, 1), simd_float4(1, 0, 0, 1)]
        for x in 0..<6 {
            let modelMatrix2 = matrix4x4_rotation(radians: Float(self.rotationZ) + theta * Float(x), axis: rotationAxis2)
            uniforms2[x].projectionMatrix = projectionMatrix
//            uniforms2[x].modelViewMatrix = simd_mul(viewMatrix2, simd_mul(modelMatrix2, simd_mul(transitionY, scaleMatrix)))
            if x % 2 == 0 {
                uniforms2[x].modelViewMatrix = simd_mul(viewMatrix2, simd_mul(modelMatrix2, simd_mul(transition2Y, simd_mul(scaleMatrix1, transition1Y))))
            }
            else {
                uniforms2[x].modelViewMatrix = simd_mul(viewMatrix2, simd_mul(modelMatrix2, simd_mul(transition2Y, simd_mul(scaleMatrix2, transition1Y))))
            }
            uniforms2[x].fg = fgs[x]
            uniforms2[x].bg = bgs[x]
        }
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
            
            if let renderPassDescriptor = renderPassDescriptor, let parallel = commandBuffer.makeParallelRenderCommandEncoder(descriptor: renderPassDescriptor) {
                
                if let renderEncoder = parallel.makeRenderCommandEncoder() {

                    /// Final pass rendering code here
                    renderEncoder.label = "Primary Render Encoder"

                    renderEncoder.pushDebugGroup("Draw Box")

                    renderEncoder.setCullMode(.back)

                    renderEncoder.setFrontFacing(.counterClockwise)

                    renderEncoder.setRenderPipelineState(pipelineState)

                    renderEncoder.setDepthStencilState(depthState)

                    renderEncoder.setVertexBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)

                    for (index, element) in mesh.vertexDescriptor.layouts.enumerated() {
                        guard let layout = element as? MDLVertexBufferLayout else {
                            return
                        }

                        if layout.stride != 0 {
                            let buffer = mesh.vertexBuffers[index]
                            renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                        }
                    }

                    renderEncoder.setFragmentTexture(colorMap, index: TextureIndex.color.rawValue)

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

//                if let renderEncoder = parallel.makeRenderCommandEncoder() {
//
//                    /// Final pass rendering code here
//                    renderEncoder.label = "Primary Render Encoder"
//
//                    renderEncoder.pushDebugGroup("Draw Box")
//
//                    renderEncoder.setCullMode(.none)
//
//                    renderEncoder.setFrontFacing(.counterClockwise)
//
//                    renderEncoder.setRenderPipelineState(pipelineState1)
//
//                    renderEncoder.setDepthStencilState(depthState)
//
//                    renderEncoder.setVertexBuffer(dynamicUniformBuffer1, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
//                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer1, offset:uniformBufferOffset, index: BufferIndex.uniforms.rawValue)
//
//                    for (index, element) in mesh1.vertexDescriptor.layouts.enumerated() {
//                        guard let layout = element as? MDLVertexBufferLayout else {
//                            return
//                        }
//
//                        if layout.stride != 0 {
//                            let buffer = mesh1.vertexBuffers[index]
//                            renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
//                        }
//                    }
//
//                    renderEncoder.setFragmentTexture(illuminati, index: TextureIndex.color.rawValue)
//
//                    for submesh in mesh1.submeshes {
//                        renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
//                                                            indexCount: submesh.indexCount,
//                                                            indexType: submesh.indexType,
//                                                            indexBuffer: submesh.indexBuffer.buffer,
//                                                            indexBufferOffset: submesh.indexBuffer.offset)
//
//                    }
//
//                    renderEncoder.popDebugGroup()
//
//                    renderEncoder.endEncoding()
//
//                }
                
                for x in 0..<6 {
                    
                    if let renderEncoder = parallel.makeRenderCommandEncoder() {
                        
                        /// Final pass rendering code here
                        renderEncoder.label = "Text Render Encoder"
                        
                        renderEncoder.pushDebugGroup("Draw Box")
                        
                        renderEncoder.setCullMode(.back)
                        
                        renderEncoder.setFrontFacing(.counterClockwise)
                        
                        renderEncoder.setRenderPipelineState(pipelineState2)
                        
                        renderEncoder.setDepthStencilState(depthState)
                        
                        renderEncoder.setFragmentSamplerState(sampler, index: 0)
                        
                        if x % 2 == 0 {
                            renderEncoder.setFragmentTexture(fontTexture1, index: TextureIndex.color.rawValue)
                        }
                        else {
                            renderEncoder.setFragmentTexture(fontTexture2, index: TextureIndex.color.rawValue)
                        }

                        renderEncoder.setVertexBuffer(dynamicUniformBuffer2, offset:sixUniformBufferOffset + uniformsSize * x, index: BufferIndex.uniforms.rawValue)
                        renderEncoder.setFragmentBuffer(dynamicUniformBuffer2, offset:sixUniformBufferOffset + uniformsSize * x, index: BufferIndex.uniforms.rawValue)
                        
                        for (index, element) in mesh2.vertexDescriptor.layouts.enumerated() {
                            guard let layout = element as? MDLVertexBufferLayout else {
                                return
                            }
                            
                            if layout.stride != 0 {
                                let buffer = mesh2.vertexBuffers[index]
                                renderEncoder.setVertexBuffer(buffer.buffer, offset:buffer.offset, index: index)
                            }
                        }
                        
                        for submesh in mesh2.submeshes {
                            renderEncoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                                                indexCount: submesh.indexCount,
                                                                indexType: submesh.indexType,
                                                                indexBuffer: submesh.indexBuffer.buffer,
                                                                indexBufferOffset: submesh.indexBuffer.offset)
                            
                        }
                        
                        renderEncoder.popDebugGroup()
                        
                        renderEncoder.endEncoding()
                    }
                }

                parallel.endEncoding()
            }
            
            if let drawable = view.currentDrawable {
                commandBuffer.present(drawable)
            }
            commandBuffer.commit()
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        /// Respond to drawable size or orientation changes here
        
        let aspect = Float(size.width) / Float(size.height)
        if aspect > 1 {
            projectionMatrix = matrix_float4x4_ortho(left: -1 * aspect, right: 1 * aspect, bottom: -1, top: 1, near: -5, far: 5)
        }
        else {
            projectionMatrix = matrix_float4x4_ortho(left: -1, right: 1, bottom: -1 / aspect, top: 1 / aspect, near: -5, far: 5)
        }
//        projectionMatrix = matrix_perspective_right_hand(fovyRadians: radians_from_degrees(65), aspectRatio: aspect, nearZ: 0.1, farZ: 100.0)
        
    }
    
    func startRotation(duration: Double, endingRotationZ: Double, timingFunction: ((_ tx: Double) -> Double)?) {
        GZLog("Rotation started")
        
        self.timingFunction = timingFunction
        if duration > 0 {
            self.beginingTime = Date().timeIntervalSince1970
            GZLog(self.beginingTime)
            GZLog(Date().timeIntervalSince1970)
            self.elapsedTime = 0
            self.endingTime = self.beginingTime + duration
            self.rotating = true
            self.rotationZ = self.rotationZ.truncatingRemainder(dividingBy: Double.pi * 2.0)
            self.beginingRotationZ = self.rotationZ
            self.endingRotationZ = endingRotationZ
        }
        else {
            self.rotating = false
        }
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

func matrix4x4_scale(_ scaleX: Float, _ scaleY: Float, _ scaleZ: Float) -> matrix_float4x4 {
    return matrix_float4x4.init(columns:(vector_float4(scaleX,  0,          0,          0),
                                         vector_float4(0,       scaleY,     0,          0),
                                         vector_float4(0,       0,          scaleZ,     0),
                                         vector_float4(0,       0,          0,          1)))
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
