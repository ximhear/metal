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
let uniformsSize = MemoryLayout<Uniforms>.size

let maxBuffersInFlight = 3

enum RendererError: Error {
    case badVertexDescriptor
}

class Renderer: NSObject, MTKViewDelegate {
    
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var dynamicUniformBuffer: MTLBuffer
    var dynamicUniformBuffer1_0: MTLBuffer
    var dynamicUniformBuffer1_1: MTLBuffer
    var dynamicUniformBuffer2: MTLBuffer
//    var pipelineState: MTLRenderPipelineState
    var pipelineState1_0: MTLRenderPipelineState
    var pipelineState1_1: MTLRenderPipelineState
    var pipelineState2: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    
    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    
    var uniformBufferOffset = 0
    var sixUniformBufferOffset1_0 = 0
    var sixUniformBufferOffset = 0

    var uniformBufferIndex = 0
    
    var uniforms: UnsafeMutablePointer<Uniforms>
    var uniforms1_0: UnsafeMutablePointer<Uniforms>
    var uniforms1_1: UnsafeMutablePointer<Uniforms>
    var uniforms2: UnsafeMutablePointer<Uniforms>

    var projectionMatrix: matrix_float4x4 = matrix_float4x4()
    
    var texture1Width: Float = 0
    var texture2Width: Float = 0
    
    var mesh: MTKMesh
    var mesh1_0: [MTKMesh]
//    var mesh1_1: MTKMesh
    var mesh2: MTKMesh
    
    var sdfGenerators: [FontAtlasGenerator]
    var samplerState: MTLSamplerState?
    var sampler: MTLSamplerState?
    
    var angleFunction: ((_ tx: Double) -> Double) = { _ in 0 }
    var speedFunction: ((_ tx: Double) -> Double) = { _ in 0 }
    var counterClockwiseRotation: Bool = true
    var beginingTime: Double = 0
    var endingTime: Double = 0
    var rotating = false
    var beginingRotationZ: Double = 0
    var endingRotationZ: Double = 0
    var elapsedTime : Double = 0
    var rotationZ : Double = 0
    var rotationEnded: (_ angle: Double) -> Void = { _ in }
    
    let items: [RouletteItem]
    
    // 패널 백그라운드
    let backgroundPatchLevel = 2
    var backgroundPatchCount: Int {
        return Int(pow(Double(4), Double(backgroundPatchLevel)))
    }
    var backgroundEdgeFactors: [Float] = [16, 16, 16]
    var backgroundInsideFactors: Float  = 16
    var backgroundControlPointsBuffer: MTLBuffer?
    var backgroundTessellationPipelineState: MTLComputePipelineState
    lazy var backgroundTessellationFactorsBuffer: MTLBuffer? = {
        // 1
        let count = backgroundPatchCount * (4 + 2)
        // 2
        let size = count * MemoryLayout<Float>.size / 2
        return Renderer.device.makeBuffer(length: size,
                                          options: .storageModePrivate)
    }()
    // 패널 사이 조각
    let linePatches = (horizontal: 2, vertical: 4)
    var linePatchCount: Int {
      return linePatches.horizontal * linePatches.vertical
    }
    var lineEdgeFactors: [Float] = [16, 4, 16, 4]
    var lineInsideFactors: [Float] = [4, 16]
    // 텍스트
    let textPatches = (horizontal: 4, vertical: 4)
    var textPatchCount: Int {
        return textPatches.horizontal * textPatches.vertical
    }
    var textEdgeFactors: [Float] = [16, 16, 16, 16]
    var textInsideFactors: [Float] = [16, 16]

    var controlPointsBuffer: MTLBuffer?
    var tessellationPipelineState: MTLComputePipelineState
    lazy var tessellationFactorsBuffer: MTLBuffer? = {
      // 1
      let count = linePatchCount * (4 + 2)
      // 2
      let size = count * MemoryLayout<Float>.size / 2
      return Renderer.device.makeBuffer(length: size,
                                  options: .storageModePrivate)
    }()
    
    var textControlPointsBuffer: MTLBuffer?
    var textTessellationPipelineState: MTLComputePipelineState

    lazy var textTessellationFactorsBuffer: MTLBuffer? = {
        // 1
        let count = textPatchCount * (4 + 2)
        // 2
        let size = count * MemoryLayout<Float>.size / 2
        return Renderer.device.makeBuffer(length: size,
                                          options: .storageModePrivate)
    }()
    
   //
    static var device: MTLDevice!
    var isFirstRendering = true
    var fillMode: MTLTriangleFillMode = .fill

    deinit {
        GZLog()
    }

    init?(metalKitView: MTKView, items: [RouletteItem]) {
        
        if items.count < 2 {
            return nil
        }

        srand48(Int(time(nil)))
        self.items = items
        
        let rouletteCount = Renderer.rouletteCount(items.count)
        let yDivideCount = 50
        
        self.device = metalKitView.device!
        Renderer.device = self.device
        guard let queue = self.device.makeCommandQueue() else { return nil }
        self.commandQueue = queue
        
        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device.makeBuffer(length:uniformBufferSize, options:[.storageModeShared]) else { return nil }
        dynamicUniformBuffer = buffer
        
        self.dynamicUniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents()).bindMemory(to:Uniforms.self, capacity:1)

        let uniformsSize = ((MemoryLayout<Uniforms>.size * self.items.count) & ~0xFF) + 0x100
        let uniformsSize1_0 = ((MemoryLayout<Uniforms>.size * rouletteCount) & ~0xFF) + 0x100
        let uniformBufferSize1_0 = uniformsSize1_0 * maxBuffersInFlight
        guard let buffer1_0 = self.device.makeBuffer(length: uniformBufferSize1_0, options: [.storageModeShared]) else { return nil }
        dynamicUniformBuffer1_0 = buffer1_0
        self.dynamicUniformBuffer1_0.label = "UniformBuffer1_0"
        uniforms1_0 = UnsafeMutableRawPointer(dynamicUniformBuffer1_0.contents()).bindMemory(to:Uniforms.self, capacity: rouletteCount)

        let uniformBufferSize1 = uniformsSize * maxBuffersInFlight
        guard let buffer1_1 = self.device.makeBuffer(length: uniformBufferSize1, options: [.storageModeShared]) else { return nil }
        dynamicUniformBuffer1_1 = buffer1_1
        self.dynamicUniformBuffer1_1.label = "UniformBuffer1_1"
        uniforms1_1 = UnsafeMutableRawPointer(dynamicUniformBuffer1_1.contents()).bindMemory(to:Uniforms.self, capacity:1)

        let uniformBufferSize2 = uniformsSize * maxBuffersInFlight
        guard let buffer2 = self.device.makeBuffer(length: uniformBufferSize2, options: [.storageModeShared]) else { return nil }
        dynamicUniformBuffer2 = buffer2
        self.dynamicUniformBuffer2.label = "UniformBuffer2"
        uniforms2 = UnsafeMutableRawPointer(dynamicUniformBuffer2.contents()).bindMemory(to:Uniforms.self, capacity: 6)

        metalKitView.depthStencilPixelFormat = MTLPixelFormat.depth32Float_stencil8
        metalKitView.colorPixelFormat = MTLPixelFormat.bgra8Unorm_srgb
        metalKitView.sampleCount = 1
        
        let mtlVertexDescriptor = Renderer.buildMetalVertexDescriptor()
        
//        do {
//            pipelineState = try Renderer.buildRenderPipelineWithDevice(device: device,
//                                                                       metalKitView: metalKitView,
//                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
//        } catch {
//            GZLog("Unable to compile render pipeline state.  Error info: \(error)")
//            return nil
//        }
        
        let descriptor1_0 = Renderer.buildMetalVertexDescriptor1_0()
        do {
            pipelineState1_0 = try Renderer.buildRenderPipelineWithDevice1_0(device: device,
                                                                             metalKitView: metalKitView,
                                                                             mtlVertexDescriptor: descriptor1_0)
        } catch {
            GZLog("Unable to compile render pipeline state.  Error info: \(error)")
            return nil
        }
        
        let mtlVertexDescriptor1_1 = Renderer.buildMetalVertexDescriptor1_1()
        do {
            pipelineState1_1 = try Renderer.buildRenderPipelineWithDevice1_1(device: device,
                                                                         metalKitView: metalKitView,
                                                                         mtlVertexDescriptor: mtlVertexDescriptor1_1)
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

        mesh1_0 = []

        let maxY: Float = 1 / cos(Float.pi / Float(Renderer.rouletteCount(self.items.count)))
        let controlPoints = Renderer.createControlPoints(patches: linePatches, size: (0.04, maxY), z: -0.01)
        controlPointsBuffer = device.makeBuffer(bytes: controlPoints, length: MemoryLayout<float3>.stride * controlPoints.count)
        
        let maxX = tan(Float.pi / Float(Renderer.rouletteCount(self.items.count)))
        let backgourndControlPoints = Renderer.createControlPoints(patchLevel: backgroundPatchLevel,
                                                                   controlPoints: [
                                                                    float3(0, 0, 0),
                                                                    float3(-maxX, 1, 0),
                                                                    float3(maxX, 1, 0),
                                                                   ])
        backgroundControlPointsBuffer = device.makeBuffer(bytes: backgourndControlPoints, length: MemoryLayout<float3>.stride * backgourndControlPoints.count)

        let textControlPoints = Renderer.createControlPoints(patches: textPatches, size: (1, 1), z: -0.011)
        textControlPointsBuffer = device.makeBuffer(bytes: textControlPoints, length: MemoryLayout<float3>.stride * textControlPoints.count)
        
        do {
            mesh2 = try Renderer.buildMesh2 (device: device, mtlVertexDescriptor: mtlVertexDescriptor, ratio: 1, divideCount: yDivideCount)
        } catch {
            GZLog("Unable to build MetalKit Mesh. Error info: \(error)")
            return nil
        }
        
        let font = UIFont.systemFont(ofSize: 128)
        
        sdfGenerators = []
        for x in items {
            let generator = FontAtlasGenerator()
            generator.createTextureData(font: font, string: x.text)
            sdfGenerators.append(generator)
        }
        
        for (index, x) in self.items.enumerated() {
            var x1: Float = 0
            var x2: Float = 0
            var p: Float = 1
            var t: Float = 1
            let generator = sdfGenerators[index]
            p = Float(generator.textureHeight) / Float(generator.textureWidth)
            t = tan(Float.pi / 2.0 - Float.pi / Float(self.items.count))
            
            x1 = (-p + sqrt(4 * p * p + 3)) / 2 / (p * p + 1)
            x2 = 0.5 / (t + p)
            x.scaleX = min(x1, x2) * 2
            x.scaleY = x.scaleX * p
            
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Unorm, width: generator.textureWidth, height: generator.textureHeight, mipmapped: false)
            textureDescriptor.usage = .shaderRead
            let region = MTLRegionMake2D(0, 0, generator.textureWidth, generator.textureHeight)
            
            x.fontTexture = device.makeTexture(descriptor: textureDescriptor)

            _ = generator.textureData?.withUnsafeBytes({ (bytes: UnsafePointer<UInt8>) -> Int  in
                x.fontTexture?.replace(region: region, mipmapLevel: 0, withBytes: bytes, bytesPerRow: generator.textureWidth)
                return 0
            })
        }


        backgroundTessellationPipelineState = Renderer.buildTriangleTesselationComputePipelineState(device: device)
        tessellationPipelineState = Renderer.buildComputePipelineState(device: device)
        textTessellationPipelineState = Renderer.buildComputePipelineState(device: device)

        super.init()
        
//        do {
//            let rouletteCount = self.rouletteCount()
////            for x in 0..<rouletteCount {
//            let a = try Renderer.buildMesh1_0(device: device,
//                                              mtlVertexDescriptor: descriptor1_0,
//                                              xDivideCount: yDivideCount,
//                                              yDivideCount: yDivideCount,
//                                              rouletteCount: rouletteCount,
//                                              color: {
//                                                let a = Float(drand48());
//                                                let b = Float(drand48());
//                                                let c = Float(drand48());
//                                                return vector_float3(a, b, c) })
//                mesh1_0.append(a)
////            }
//        } catch {
//            GZLog("Unable to build MetalKit Mesh. Error info: \(error)")
//            return nil
//        }
        
        buildSamplerState()
    }
    
    func uniformsSizeForRouletteItems() -> Int {
        return ((MemoryLayout<Uniforms>.size * self.items.count) & ~0xFF) + 0x100
    }

    func uniformsSizeForRouletteCount() -> Int {
        return ((MemoryLayout<Uniforms>.size * rouletteCount()) & ~0xFF) + 0x100
    }

    class func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
        // Creete a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = .float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = .float2
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = MemoryLayout<float3>.stride
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = .perPatchControlPoint
        
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildMetalVertexDescriptor1_0() -> MTLVertexDescriptor {
        // Creete a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = .float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float3
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
//        mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = MemoryLayout<float3>.stride
//        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = .perPatchControlPoint
        
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 12
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
//        mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
        
        return mtlVertexDescriptor
    }
    
    class func buildMetalVertexDescriptor1_1() -> MTLVertexDescriptor {
        // Creete a Metal vertex descriptor specifying how vertices will by laid out for input into our render
        //   pipeline and how we'll layout our Model IO vertices
        
        let mtlVertexDescriptor = MTLVertexDescriptor()
        
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = .float3
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
        mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
        
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = MemoryLayout<float3>.stride
//        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
        mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = .perPatchControlPoint

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
    
    class func buildRenderPipelineWithDevice1_0(device: MTLDevice,
                                              metalKitView: MTKView,
                                              mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "instanceRenderingColoredVertexShader")
        let fragmentFunction = library?.makeFunction(name: "instanceRenderingColoredFragmentShader")
        
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
    
    class func buildRenderPipelineWithDevice1_1(device: MTLDevice,
                                                metalKitView: MTKView,
                                                mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
        /// Build a render state pipeline object
        
        let library = device.makeDefaultLibrary()
        
        let vertexFunction = library?.makeFunction(name: "tessellationInstanceRenderingColoredVertexShader")
        let fragmentFunction = library?.makeFunction(name: "instanceRenderingColoredFragmentShader")
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "RenderPipeline1"
        descriptor.sampleCount = metalKitView.sampleCount
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.vertexDescriptor = mtlVertexDescriptor
        
        descriptor.colorAttachments[0].pixelFormat = metalKitView.colorPixelFormat
        if let attachment = descriptor.colorAttachments[0] {
            attachment.isBlendingEnabled = true
            attachment.rgbBlendOperation = .add
            attachment.sourceRGBBlendFactor = .sourceAlpha
            attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        }
        descriptor.depthAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        descriptor.stencilAttachmentPixelFormat = metalKitView.depthStencilPixelFormat
        
        return try device.makeRenderPipelineState(descriptor: descriptor)
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
    
    static func buildComputePipelineState(device: MTLDevice) -> MTLComputePipelineState {

        let library = device.makeDefaultLibrary()
      guard let kernelFunction = library?.makeFunction(name: "tessellation_main") else {
          fatalError("Tessellation shader function not found")
      }
      return try! device.makeComputePipelineState(
                             function: kernelFunction)
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

    static func buildTriangleTesselationComputePipelineState(device: MTLDevice) -> MTLComputePipelineState {

        let library = device.makeDefaultLibrary()
      guard let kernelFunction = library?.makeFunction(name: "tessellation_triangle_main") else {
          fatalError("Tessellation shader function not found")
      }
      return try! device.makeComputePipelineState(
                             function: kernelFunction)
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
    
    class func generateVertexIndices(vertexIndices1: [Int], vertexIndices2: [Int]) -> [(Int, Int, Int)]? {
        
        var firstIndices: [Int]!
        var secondIndices: [Int]!
        
        if vertexIndices1.count >= vertexIndices2.count {
            firstIndices = vertexIndices1
            secondIndices = vertexIndices2
        }
        else {
            firstIndices = vertexIndices2
            secondIndices = vertexIndices1
        }
        
        var tempIndices: [Int] = []
        let ratio = Double(secondIndices.count) / Double(firstIndices.count)
        
        for x in (0..<firstIndices.count) {
            tempIndices.append(Int(ratio * Double(x)))
        }
        
        var indices: [(Int, Int, Int)] = []
        for (x, vertexIndex) in firstIndices.enumerated() {
            if x == firstIndices.count - 1 {
                break
            }
            indices.append((firstIndices[x + 1], vertexIndex, secondIndices[tempIndices[x]]))
        }
        
//        GZLog(tempIndices)
        for (x, index) in tempIndices.enumerated() {
            if x == tempIndices.count - 1 {
                break
            }
            if index != tempIndices[x + 1] {
                indices.append((secondIndices[index], secondIndices[tempIndices[x + 1]], firstIndices[x + 1]))
            }
        }
        
        if indices.count == 0 {
            return nil
        }
        
        return indices
    }

    class func buildMesh1_0(device: MTLDevice,
                          mtlVertexDescriptor: MTLVertexDescriptor,
                          xDivideCount: Int,
                          yDivideCount: Int,
                          rouletteCount: Int,
                          color: () -> vector_float3) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeColor
        
        var xVertexCounts: [Int] = []
        if rouletteCount == 2 {
            for y in 0...yDivideCount {
                xVertexCounts.append(xDivideCount + 1)
            }
        }
        else {
            for y in 0...yDivideCount {
                let count = Int((Float(yDivideCount - y) * Float(xDivideCount + 1) + 1 * Float(y)) / Float(yDivideCount))
                if y < yDivideCount && count == 1 {
                    xVertexCounts.append(2)
                }
                else {
                    xVertexCounts.append(count)
                }
            }
        }
        
        GZLog(xVertexCounts)
        let totalVetexCount = xVertexCounts.reduce(0) { $0 + $1 }
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let vertexBuffer1 = metalAllocator.newBuffer(totalVetexCount * 3 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer
        let vertexBuffer2 = metalAllocator.newBuffer(totalVetexCount * 3 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer
        
        let maxY: Float = 1
        let maxX = tan(Float.pi / Float(rouletteCount))
        let vertices = UnsafeMutableRawPointer(vertexBuffer1.buffer.contents()).bindMemory(to:Float.self, capacity: totalVetexCount * 3)
        var verticesIndex: Int = 0
        let z: Float = 0
        for (index, count) in xVertexCounts.enumerated() {
            let y = Float(yDivideCount - index) * maxY / Float(yDivideCount)
            let x = rouletteCount == 2 ? -maxX : Float(yDivideCount - index) * -maxX / Float(yDivideCount)
            var xOffset: Float = 0
            if xVertexCounts.count - 1 == index {
                if rouletteCount == 2 { // 2일 경우에는 한점으로 모이지 않는다.
                    xOffset = -2 * x / Float(count - 1)
                }
                else {
                    xOffset = 0 // 마지막은 한점(0)으로 모인다.
                }
            }
            else {
                xOffset = -2 * x / Float(count - 1)
            }
            for xIndex in 0..<count {
                vertices[verticesIndex] = x + xOffset * Float(xIndex)
                verticesIndex += 1
                vertices[verticesIndex] = y
                verticesIndex += 1
                vertices[verticesIndex] = z
                verticesIndex += 1
            }
        }

        let vertices1 = UnsafeMutableRawPointer(vertexBuffer2.buffer.contents()).bindMemory(to:Float.self, capacity: totalVetexCount * 3)
        for x in 0..<totalVetexCount {
            let a = color()
            vertices1[x * 3 + 0] = a.x
            vertices1[x * 3 + 1] = a.y
            vertices1[x * 3 + 2] = a.z
        }
        
        var yVertexIndices: [[Int]] = []
        var accumulatedCount: Int = 0
        for count in xVertexCounts {
            var a = [Int]()
            for index in(accumulatedCount..<(accumulatedCount + count)) {
                a.append(index)
            }
            accumulatedCount += count
            yVertexIndices.append(a)
        }
        
        var triangles = [(Int, Int, Int)]()
        
        for (index, vertexInices1) in yVertexIndices.enumerated() {
            if index == yVertexIndices.count - 1 {
                break
            }
            let vertexIndex2 = yVertexIndices[index + 1]
            if let a = generateVertexIndices(vertexIndices1: vertexInices1, vertexIndices2: vertexIndex2) {
                triangles.append(contentsOf: a)
            }
        }
        
        let indexBuffer1 = metalAllocator.newBuffer(triangles.count * 3 * MemoryLayout<UInt16>.stride, type: .index) as! MTKMeshBuffer
        let index1 = UnsafeMutableRawPointer(indexBuffer1.buffer.contents()).bindMemory(to:UInt16.self, capacity: triangles.count * 3)
        for (index, triangle) in triangles.enumerated() {
            index1[index * 3 + 0] = UInt16(triangle.0)
            index1[index * 3 + 1] = UInt16(triangle.1)
            index1[index * 3 + 2] = UInt16(triangle.2)
        }
        
        
        let submesh1 = MDLSubmesh.init(indexBuffer: indexBuffer1, indexCount: triangles.count * 3, indexType: .uInt16, geometryType: .triangles, material: nil)
        let mdlMesh1 = MDLMesh.init(vertexBuffers: [vertexBuffer1, vertexBuffer2], vertexCount: totalVetexCount, descriptor: mdlVertexDescriptor, submeshes: [submesh1])
        
        return try MTKMesh(mesh:mdlMesh1, device:device)
    }

    class func buildMesh1_1(device: MTLDevice,
                          mtlVertexDescriptor: MTLVertexDescriptor,
                          xDivideCount: Int,
                          yDivideCount: Int,
                          rouletteCount: Int,
                          width: Float) throws -> MTKMesh {
        /// Create and condition mesh data to feed into a pipeline using the given vertex descriptor
        
        let mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(mtlVertexDescriptor)
        
        guard let attributes = mdlVertexDescriptor.attributes as? [MDLVertexAttribute] else {
            throw RendererError.badVertexDescriptor
        }
        attributes[VertexAttribute.position.rawValue].name = MDLVertexAttributePosition
        attributes[VertexAttribute.texcoord.rawValue].name = MDLVertexAttributeColor
        
        let totalVetexCount = (xDivideCount + 1) * (yDivideCount + 1)
        
        let metalAllocator = MTKMeshBufferAllocator(device: device)
        
        let vertexBuffer1 = metalAllocator.newBuffer(totalVetexCount * 3 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer
        let vertexBuffer2 = metalAllocator.newBuffer(totalVetexCount * 3 * MemoryLayout<Float>.stride, type: .vertex) as! MTKMeshBuffer
        
        let maxY: Float = 1 / cos(Float.pi / Float(self.rouletteCount(rouletteCount)))
        let vertices = UnsafeMutableRawPointer(vertexBuffer1.buffer.contents()).bindMemory(to:Float.self, capacity: totalVetexCount * 3)
        var verticesIndex: Int = 0
        let z: Float = 0
        let xOffset: Float = width / Float(xDivideCount)
        for index in 0...yDivideCount {
            let y = Float(yDivideCount - index) * maxY / Float(yDivideCount)
            let x = -width / 2
            for xIndex in 0...xDivideCount {
                vertices[verticesIndex] = x + xOffset * Float(xIndex)
                verticesIndex += 1
                vertices[verticesIndex] = y
                verticesIndex += 1
                vertices[verticesIndex] = z
                verticesIndex += 1
            }
        }
        
        let vertices1 = UnsafeMutableRawPointer(vertexBuffer2.buffer.contents()).bindMemory(to:Float.self, capacity: totalVetexCount * 3)
        for x in 0..<totalVetexCount {
            vertices1[x * 3 + 0] = 0.5 + 0.5 * Float(drand48())
            vertices1[x * 3 + 1] = 0.5 + 0.5 * Float(drand48())
            vertices1[x * 3 + 2] = 0.5 + 0.5 * Float(drand48())
        }
        
        var yVertexIndices: [[Int]] = []
        var accumulatedCount: Int = 0
        for _ in 0...yDivideCount {
            let count = xDivideCount + 1
            var a = [Int]()
            for index in (accumulatedCount..<(accumulatedCount + count)) {
                a.append(index)
            }
            accumulatedCount += count
            yVertexIndices.append(a)
        }
        
        var triangles = [(Int, Int, Int)]()
        
        for (index, vertexInices1) in yVertexIndices.enumerated() {
            if index == yVertexIndices.count - 1 {
                break
            }
            let vertexIndex2 = yVertexIndices[index + 1]
            if let a = generateVertexIndices(vertexIndices1: vertexInices1, vertexIndices2: vertexIndex2) {
                triangles.append(contentsOf: a)
            }
        }
        
        let indexBuffer1 = metalAllocator.newBuffer(triangles.count * 3 * MemoryLayout<UInt16>.stride, type: .index) as! MTKMeshBuffer
        let index1 = UnsafeMutableRawPointer(indexBuffer1.buffer.contents()).bindMemory(to:UInt16.self, capacity: triangles.count * 3)
        for (index, triangle) in triangles.enumerated() {
            index1[index * 3 + 0] = UInt16(triangle.0)
            index1[index * 3 + 1] = UInt16(triangle.1)
            index1[index * 3 + 2] = UInt16(triangle.2)
        }
        
        
        let submesh = MDLSubmesh.init(indexBuffer: indexBuffer1, indexCount: triangles.count * 3, indexType: .uInt16, geometryType: .triangles, material: nil)
        let mdlMesh = MDLMesh.init(vertexBuffers: [vertexBuffer1, vertexBuffer2], vertexCount: totalVetexCount, descriptor: mdlVertexDescriptor, submeshes: [submesh])
        
        return try MTKMesh(mesh:mdlMesh, device:device)
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
    
    static func rouletteCount(_ count: Int) -> Int {

        switch count {
        case 2:
            return 6
        case 3:
            return 6
        case 4:
            return 8
        case 5:
            return 10
        default:
            return count
        }
    }
    
    static func createControlPoints(patches: (horizontal: Int, vertical: Int),
                                    size: (width: Float, height: Float), z: Float) -> [float4] {
      
      var points: [float4] = []
      // per patch width and height
      let width = 1 / Float(patches.horizontal)
      let height = 1 / Float(patches.vertical)
      
      for j in 0..<patches.vertical {
        let row = Float(j)
        for i in 0..<patches.horizontal {
          let column = Float(i)
          let left = width * column
          let bottom = height * row
          let right = width * column + width
          let top = height * row + height
          
            points.append([left, top, -0, 1])
            points.append([right, top, -0, 1])
            points.append([right, bottom, -0, 1])
            points.append([left, bottom, -0, 1])
        }
      }
      // size and convert to Metal coordinates
      // eg. 6 across would be -3 to + 3
      points = points.map {
        [$0.x * size.width - size.width / 2,
         $0.y * size.height,
         z, 1]
      }
      return points
    }

    static func createControlPoints(patchLevel: Int, controlPoints c: [float3]) -> [float3] {
      
        if patchLevel == 0 {
            return c
        }
        var points: [float3] = []
        
        var m: [float3] = []
        m.append((c[0] + c[1]) / 2)
        m.append((c[1] + c[2]) / 2)
        m.append((c[2] + c[0]) / 2)
        points.append(contentsOf: createControlPoints(patchLevel: patchLevel - 1, controlPoints: [c[0], m[0], m[2]]))
        points.append(contentsOf: createControlPoints(patchLevel: patchLevel - 1, controlPoints: [m[0], c[1], m[1]]))
        points.append(contentsOf: createControlPoints(patchLevel: patchLevel - 1, controlPoints: [m[1], c[2], m[2]]))
        points.append(contentsOf: createControlPoints(patchLevel: patchLevel - 1, controlPoints: [m[0], m[1], m[2]]))
      return points
    }

    static func createBackgroundControlPoints(patches: (horizontal: Int, vertical: Int),
                                    size: (width: Float, height: Float)) -> [float4] {
        
        var points: [float4] = []
        // per patch width and height
        let width = 1 / Float(patches.horizontal)
        let height = 1 / Float(patches.vertical)
        
        for j in 0..<patches.vertical {
            let row = Float(j)
            for i in 0..<patches.horizontal {
                let column = Float(i)
                let left = width * column
                let bottom = height * row
                let right = width * column + width
                let top = height * row + height
                
                points.append([left, top, -0, 1])
                points.append([right, top, -0, 1])
                points.append([right, bottom, -0, 1])
                points.append([left, bottom, -0, 1])
            }
        }
        // size and convert to Metal coordinates
        // eg. 6 across would be -3 to + 3
        points = points.map {
            [$0.x * size.width - size.width / 2,
             $0.y * size.height,
             -0.01, 1]
        }
        return points
    }
    
    func rouletteCount() -> Int {
        
        return Renderer.rouletteCount(self.items.count)
    }
    
    func orgCount() -> Int {
        return self.items.count
    }
    
    func sectorToIndex(sector: Int) -> Int {
        
        return sector * orgCount() / rouletteCount()
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(dynamicUniformBuffer.contents() + uniformBufferOffset).bindMemory(to:Uniforms.self, capacity:1)

        sixUniformBufferOffset = uniformsSizeForRouletteItems() * uniformBufferIndex
        sixUniformBufferOffset1_0 = (((MemoryLayout<Uniforms>.size * self.rouletteCount()) & ~0xFF) + 0x100) * uniformBufferIndex
        
        
        uniforms1_0 = UnsafeMutableRawPointer(dynamicUniformBuffer1_0.contents() + sixUniformBufferOffset1_0).bindMemory(to:Uniforms.self, capacity: rouletteCount())
        uniforms1_1 = UnsafeMutableRawPointer(dynamicUniformBuffer1_1.contents() + sixUniformBufferOffset).bindMemory(to:Uniforms.self, capacity: orgCount())

        uniforms2 = UnsafeMutableRawPointer(dynamicUniformBuffer2.contents() + sixUniformBufferOffset).bindMemory(to:Uniforms.self, capacity: orgCount())
    }
    
    private func updateGameState() {
        /// Update any game state before rendering
        
        uniforms[0].projectionMatrix = projectionMatrix
        
        
        var speed: Float = 0
        if self.rotating == true {
            elapsedTime = Date().timeIntervalSince1970 - self.beginingTime
            
            if self.beginingTime + elapsedTime >= self.endingTime {
                self.rotationZ = self.endingRotationZ
                self.rotating = false
                self.rotationEnded(self.rotationZ)
                GZLog("Rotation ended")
            }
            else {
                var result: Double = 0
                let x = elapsedTime / (self.endingTime - self.beginingTime)
                result = beginingRotationZ + angleFunction(x)
                self.rotationZ = result
                speed = Float(speedFunction(elapsedTime))
            }
        }

        let rouletteCount = Float(self.items.count)
        let rotationAxis = float3(0, 0, 1)
        let modelMatrix = matrix4x4_rotation(radians: Float(self.rotationZ), axis: rotationAxis)
        let viewMatrix = matrix4x4_translation(0.0, 0.0, -3.5)
        uniforms[0].modelViewMatrix = simd_mul(viewMatrix, modelMatrix)
        
        let rotationAxis2 = float3(0, 0, 1)
        let viewMatrix2 = matrix4x4_translation(0.0, 0.0, -3.2)
        
        let radius: Float = 1
        let theta = Float.pi * 2.0 / rouletteCount
        let ratio: Float = 1.0 / 10.0
        let moveY = radius * cos(theta / 2.0) * ratio
        let scaleX = radius * sin(theta / 2.0) * 2
        let scaleY = radius * cos(theta / 2.0) - moveY
        let scaleZ: Float = 1
        
        let scaleMatrix = matrix4x4_scale(scaleX, scaleY, scaleZ)
        let transitionY = matrix4x4_translation(0, moveY, 0)
        
        let transition1Y = matrix4x4_translation(0, -0.5, 0)
        let transition2Y = matrix4x4_translation(0, 0.5, 0)

        let fgs = [simd_float4(1, 0, 0, 1), simd_float4(0, 1, 0, 1), simd_float4(0, 0, 1, 1), simd_float4(1, 1, 0, 1), simd_float4(1, 0, 1, 1), simd_float4(0, 1, 1, 1)]
        let bgs = [simd_float4(0, 1, 1, 1), simd_float4(1, 0, 1, 1), simd_float4(1, 1, 0, 1), simd_float4(0, 0, 1, 1), simd_float4(0, 1, 0, 1), simd_float4(1, 0, 0, 1)]
        for (x, item) in self.items.enumerated() {
            let scaleMatrix = matrix4x4_scale(item.scaleX, item.scaleY, 1)
            
            let modelMatrix2 = matrix4x4_rotation(radians: Float(self.rotationZ) + theta * Float(x), axis: rotationAxis2)
            uniforms2[x].projectionMatrix = projectionMatrix
            uniforms2[x].modelViewMatrix = simd_mul(viewMatrix2, simd_mul(modelMatrix2, simd_mul(transition2Y, simd_mul(scaleMatrix, transition1Y))))
            uniforms2[x].fg = item.textColor
            uniforms2[x].bg = item.bgColor
            uniforms2[x].speed = counterClockwiseRotation == true ? speed : -speed
        }
        
        
        
//        uniforms1[0].projectionMatrix = projectionMatrix
//        let viewMatrix1 = matrix4x4_translation(0.0, 0.0, -3.3)
//        uniforms1[0].modelViewMatrix = simd_mul(viewMatrix1, modelMatrix)
        let viewMatrix1_0 = matrix4x4_translation(0.0, 0.0, -3.5)
        let viewMatrix1_1 = matrix4x4_translation(0.0, 0.0, -3.4)
        
        let rc = self.rouletteCount()
        let theta1 = Float.pi * 2.0 / Float(rc)
        var offsetTheta: Float = 0
        if self.rouletteCount() > orgCount() {
            offsetTheta = theta1 * Float(self.rouletteCount() / orgCount() - 1) / 2
        }
        for x in 0..<rc {
            let index = x * orgCount() / rc
            let item = self.items[index]
            let modelMatrix1_0 = matrix4x4_rotation(radians: Float(self.rotationZ) + theta1 * Float(x) - offsetTheta, axis: rotationAxis2)
            uniforms1_0[x].projectionMatrix = projectionMatrix
            uniforms1_0[x].modelViewMatrix = simd_mul(viewMatrix1_0, modelMatrix1_0)
            uniforms1_0[x].fg = item.color
            uniforms1_0[x].bg = item.bgColor
            uniforms1_0[x].speed = counterClockwiseRotation == true ? speed : -speed
        }

        for (x, item) in self.items.enumerated() {
            let modelMatrix1_1 = matrix4x4_rotation(radians: Float(self.rotationZ) + theta * Float(x) + theta / 2, axis: rotationAxis2)
            uniforms1_1[x].projectionMatrix = projectionMatrix
            uniforms1_1[x].modelViewMatrix = simd_mul(viewMatrix1_1, modelMatrix1_1)
            uniforms1_1[x].separatorRotationMatrix1 = matrix4x4_rotation(radians: theta1 / 2, axis: rotationAxis2)
            uniforms1_1[x].separatorRotationMatrix2 = matrix4x4_rotation(radians: -theta1 / 2, axis: rotationAxis2)
            uniforms1_1[x].fg = simd_float4(1, 1, 1, 1)
            uniforms1_1[x].speed = counterClockwiseRotation == true ? speed : -speed
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
            
            if let renderPassDescriptor = renderPassDescriptor {
                //
                if isFirstRendering == true {
                   isFirstRendering = false
                    
                    let computeEncoder1 = commandBuffer.makeComputeCommandEncoder()!
                    computeEncoder1.setComputePipelineState(backgroundTessellationPipelineState)
                    computeEncoder1.setBytes(&backgroundEdgeFactors,
                                             length: MemoryLayout<Float>.size * backgroundEdgeFactors.count,
                                             index: 0)
                    computeEncoder1.setBytes(&backgroundInsideFactors,
                                             length: MemoryLayout<Float>.size,
                                             index: 1)
                    computeEncoder1.setBuffer(backgroundTessellationFactorsBuffer, offset: 0,
                                              index: 2)
                    let backgroundWidth = min(backgroundPatchCount,
                                              backgroundTessellationPipelineState.threadExecutionWidth)
                    computeEncoder1.dispatchThreadgroups(MTLSizeMake(backgroundPatchCount, 1, 1),
                                                         threadsPerThreadgroup: MTLSizeMake(backgroundWidth, 1, 1))
                    computeEncoder1.endEncoding()
                    
                    //
                    let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
                    computeEncoder.setComputePipelineState(tessellationPipelineState)
                    computeEncoder.setBytes(&lineEdgeFactors,
                                            length: MemoryLayout<Float>.size * lineEdgeFactors.count,
                                            index: 0)
                    computeEncoder.setBytes(&lineInsideFactors,
                                            length: MemoryLayout<Float>.size * lineInsideFactors.count,
                                            index: 1)
                    computeEncoder.setBuffer(tessellationFactorsBuffer, offset: 0,
                                             index: 2)
                    let width = min(linePatchCount,
                                    tessellationPipelineState.threadExecutionWidth)
                    computeEncoder.dispatchThreadgroups(MTLSizeMake(linePatchCount,
                                                                    1, 1),
                                                        threadsPerThreadgroup: MTLSizeMake(width, 1, 1))
                    computeEncoder.endEncoding()
                    
                    let textComputeEncoder = commandBuffer.makeComputeCommandEncoder()!
                    textComputeEncoder.setComputePipelineState(textTessellationPipelineState)
                    textComputeEncoder.setBytes(&textEdgeFactors,
                                                length: MemoryLayout<Float>.size * textEdgeFactors.count,
                                                index: 0)
                    textComputeEncoder.setBytes(&textInsideFactors,
                                                length: MemoryLayout<Float>.size * textInsideFactors.count,
                                                index: 1)
                    textComputeEncoder.setBuffer(tessellationFactorsBuffer, offset: 0,
                                                 index: 2)
                    let textWidth = min(textPatchCount,
                                        textTessellationPipelineState.threadExecutionWidth)
                    textComputeEncoder.dispatchThreadgroups(MTLSizeMake(textPatchCount, 1, 1),
                                                            threadsPerThreadgroup: MTLSizeMake(textWidth, 1, 1))
                    textComputeEncoder.endEncoding()
                }



                if let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {

                    // 1
                    renderEncoder.label = "Primary Render Encoder"
                    renderEncoder.pushDebugGroup("background")
                    //                        renderEncoder.setCullMode(.back)
                    //                        renderEncoder.setFrontFacing(.counterClockwise)
                    renderEncoder.setRenderPipelineState(pipelineState1_0)
                    renderEncoder.setDepthStencilState(depthState)
                    renderEncoder.setTessellationFactorBuffer(
                        backgroundTessellationFactorsBuffer,
                        offset: 0, instanceStride: 0)
                    renderEncoder.setTriangleFillMode(fillMode)

                    renderEncoder.setVertexBuffer(dynamicUniformBuffer1_0, offset:sixUniformBufferOffset1_0, index: BufferIndex.uniforms.rawValue)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer1_0, offset:sixUniformBufferOffset1_0, index: BufferIndex.uniforms.rawValue)

                    renderEncoder.setVertexBuffer(backgroundControlPointsBuffer,
                                                  offset: 0, index: 0)

                    renderEncoder.drawPatches(numberOfPatchControlPoints: 3,
                                              patchStart: 0, patchCount: backgroundPatchCount,
                                              patchIndexBuffer: nil,
                                              patchIndexBufferOffset: 0,
                                              instanceCount: rouletteCount(), baseInstance: 0)
                    renderEncoder.popDebugGroup()

                    // 2
//                    renderEncoder.label = "Primary Render Encoder"
                    renderEncoder.pushDebugGroup("Draw separator line")
                    //                        renderEncoder.setCullMode(.back)
                    //                        renderEncoder.setFrontFacing(.counterClockwise)
                    renderEncoder.setRenderPipelineState(pipelineState1_1)
//                    renderEncoder.setDepthStencilState(depthState)
                    renderEncoder.setTessellationFactorBuffer(
                        tessellationFactorsBuffer,
                        offset: 0, instanceStride: 0)
                    renderEncoder.setTriangleFillMode(fillMode)

                    renderEncoder.setVertexBuffer(dynamicUniformBuffer1_1, offset:sixUniformBufferOffset, index: BufferIndex.uniforms.rawValue)
                    renderEncoder.setFragmentBuffer(dynamicUniformBuffer1_1, offset:sixUniformBufferOffset, index: BufferIndex.uniforms.rawValue)

                    renderEncoder.setVertexBuffer(controlPointsBuffer, offset: 0, index: 0)

                    renderEncoder.drawPatches(numberOfPatchControlPoints: 4,
                                              patchStart: 0, patchCount: linePatchCount,
                                              patchIndexBuffer: nil,
                                              patchIndexBufferOffset: 0,
                                              instanceCount: orgCount(), baseInstance: 0)
                    renderEncoder.popDebugGroup()

//                    renderEncoder.label = "Text Render Encoder"
                    renderEncoder.pushDebugGroup("Draw text")
                    renderEncoder.setCullMode(.back)
                    renderEncoder.setFrontFacing(.counterClockwise)
                    renderEncoder.setRenderPipelineState(pipelineState2)
//                    renderEncoder.setDepthStencilState(depthState)
                    renderEncoder.setFragmentSamplerState(sampler, index: 0)
                    var row: float4 = float4(Float(textPatches.vertical), 0,0, 0)
                    var col: float4 = float4(Float(textPatches.horizontal), 0, 0, 0)
                    renderEncoder.setVertexBytes(&row, length: MemoryLayout<float4>.size, index: 3)
                    renderEncoder.setVertexBytes(&col, length: MemoryLayout<float4>.size, index: 4)
                    renderEncoder.setTessellationFactorBuffer(textTessellationFactorsBuffer, offset: 0, instanceStride: 0)
                    renderEncoder.setVertexBuffer(textControlPointsBuffer, offset: 0, index: 0)
                    renderEncoder.setTriangleFillMode(fillMode)
                    for (x, item) in self.items.enumerated() {

                        /// Final pass rendering code here
                        renderEncoder.setFragmentTexture(item.fontTexture, index: TextureIndex.color.rawValue)
                        renderEncoder.setVertexBuffer(dynamicUniformBuffer2, offset:sixUniformBufferOffset + uniformsSize * x, index: BufferIndex.uniforms.rawValue)
                        renderEncoder.setFragmentBuffer(dynamicUniformBuffer2, offset:sixUniformBufferOffset + uniformsSize * x, index: BufferIndex.uniforms.rawValue)

                        renderEncoder.drawPatches(numberOfPatchControlPoints: 4,
                                                  patchStart: 0, patchCount: textPatchCount,
                                                  patchIndexBuffer: nil,
                                                  patchIndexBufferOffset: 0,
                                                  instanceCount: 1, baseInstance: 0)

                    }
                    renderEncoder.popDebugGroup()
                    
                    renderEncoder.endEncoding()
                }
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
    
    func startRotation(duration: Double, endingRotationZ: Double, counterClockwise: Bool, angleFunction: @escaping (_ tx: Double) -> Double, speedFunction: @escaping (_ tx: Double) -> Double) {
        GZLog("Rotation started")
        
        self.angleFunction = angleFunction
        self.speedFunction = speedFunction
        counterClockwiseRotation = counterClockwise
        if duration > 0 {
            self.beginingTime = Date().timeIntervalSince1970
            GZLog(self.beginingTime)
            GZLog(Date().timeIntervalSince1970)
            self.elapsedTime = 0
            self.endingTime = self.beginingTime + duration
            self.rotating = true
            self.rotationZ = self.rotationZ.truncatingRemainder(dividingBy: Double.pi * 2.0)
            self.beginingRotationZ = self.rotationZ
            self.endingRotationZ = self.rotationZ + endingRotationZ
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
