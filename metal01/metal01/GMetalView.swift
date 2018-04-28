//
//  GMetalView.swift
//  metal01
//
//  Created by LEE CHUL HYUN on 4/21/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import UIKit
import Metal
import simd
import QuartzCore

let alignedUniformsSize = (MemoryLayout<GUniforms>.size & ~0xFF) + 0x100
let maxBuffersInFlight = 3

class GMetalView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    var metalLayer: CAMetalLayer {
        return self.layer as! CAMetalLayer
    }
    
    var device: MTLDevice?
    var commandQueue: MTLCommandQueue?
    var vertexBuffer: MTLBuffer?
    var indexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer
    var pipeline: MTLRenderPipelineState?
    var depthStencilState : MTLDepthStencilState?
    var depthTexture : MTLTexture?
    var displayLink: CADisplayLink?

    var elapsedTime : Float = 0
    var rotationX : Float = 0
    var rotationY : Float = 0

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    var uniformBufferOffset = 0
    var uniformBufferIndex = 0
    var uniforms: UnsafeMutablePointer<GUniforms>

    required init?(coder aDecoder: NSCoder) {
 
        device = MTLCreateSystemDefaultDevice()

        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device?.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        uniformBuffer = buffer
        
        self.uniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(uniformBuffer.contents()).bindMemory(to:GUniforms.self, capacity:1)

        super.init(coder: aDecoder)
        
        makeDevice()
        makeBuffers()
        makePipeline()
    }
    
    func makeDevice() {
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
    }
    
    let vertices: [GVertex] = [
        GVertex.init(position: .init(-1, 1, 1, 1), color: .init(0, 1, 1, 1)),
        GVertex.init(position: .init(-1, -1, 1, 1), color: .init(0, 0, 1, 1)),
        GVertex.init(position: .init(1, -1, 1, 1), color: .init(1, 0, 1, 1)),
        GVertex.init(position: .init(1, 1, 1, 1), color: .init(1, 1, 1, 1)),
        GVertex.init(position: .init(-1, 1, -1, 1), color: .init(0, 1, 0, 1)),
        GVertex.init(position: .init(-1, -1, -1, 1), color: .init(0, 0, 0, 1)),
        GVertex.init(position: .init(1, -1, -1, 1), color: .init(1, 0, 0, 1)),
        GVertex.init(position: .init(1, 1, -1, 1), color: .init(1, 1, 0, 1))
    ]
    
    let indices: [UInt16] = [
        3, 2, 6, 6, 7, 3,
        4, 5, 1, 1, 0, 4,
        4, 0, 3, 3, 7, 4,
        1, 5, 6, 6, 2, 1,
        0, 1, 2, 2, 3, 0,
        7, 6, 5, 5, 4, 7
    ]
    
    func makeBuffers() {
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<GVertex>.stride, options: .cpuCacheModeWriteCombined)
        indexBuffer = device?.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .cpuCacheModeWriteCombined)
    }
    
    func makePipeline() {
        let library = device?.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertex_main")
        let fragmentFunc = library?.makeFunction(name: "fragment_main")
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = self.metalLayer.pixelFormat
        descriptor.depthAttachmentPixelFormat = .depth32Float
        pipeline = try? device!.makeRenderPipelineState(descriptor: descriptor)
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        self.depthStencilState = self.device?.makeDepthStencilState(descriptor: depthStencilDescriptor)
    }

    func makeDepthTexture() {
        let drawableSize = self.metalLayer.drawableSize
        
        if let texture = self.depthTexture {
            if Int(drawableSize.width) == texture.width && Int(drawableSize.height) == texture.height {
                return
            }
        }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
        desc.usage = .renderTarget
        depthTexture = self.device?.makeTexture(descriptor: desc)
    }

    override class var layerClass: AnyClass {
        return CAMetalLayer.self
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if self.superview != nil {
            displayLink = CADisplayLink.init(target: self, selector: #selector(displayLinkDidFire(displayLink:)))
            displayLink?.add(to: RunLoop.main, forMode: .commonModes)
        }
        else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    @objc func displayLinkDidFire(displayLink: CADisplayLink) {
        let duration : Float = 1.0 / 60.0
        elapsedTime += duration
        self.rotationX += duration * Float(Double.pi / 2);
        self.rotationY += duration * Float(Double.pi / 3);
        redraw()
    }
    
    private func updateDynamicBufferState() {
        /// Update the state of our uniform buffers before rendering
        
        uniformBufferIndex = (uniformBufferIndex + 1) % maxBuffersInFlight
        
        uniformBufferOffset = alignedUniformsSize * uniformBufferIndex
        
        uniforms = UnsafeMutableRawPointer(uniformBuffer.contents() + uniformBufferOffset).bindMemory(to:GUniforms.self, capacity:1)
    }
    
    func redraw() {
        guard let drawable = self.metalLayer.nextDrawable() else {
            return
        }
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        self.updateDynamicBufferState()

        let texture = drawable.texture

        let scaleFactor = sin(5 * self.elapsedTime) * 0.25 + 1
        let xAxis = vector_float3(1, 0, 0)
        let yAxis = vector_float3(0, 1, 0)
        let xRot = matrix_float4x4_rotation(axis: xAxis, angle: rotationX)
        let yRot = matrix_float4x4_rotation(axis: yAxis, angle: rotationY)
        let scale = matrix_float4x4_uniform_scale(scale: scaleFactor)
        let modelMatrix = matrix_multiply(matrix_multiply(xRot, yRot), scale)
        
        let cameraTranslation = vector_float3(0, 0, -5)
        let viewMatrix = matrix_float4x4_translation(t: cameraTranslation)
        
        let drawableSize = self.metalLayer.drawableSize
        let aspect = Float(drawableSize.width / drawableSize.height)
        let fov = Float(2 * Double.pi) / 5
        let near : Float = 1
        let far : Float = 100
        let projectionMatrix = matrix_float4x4_perspective(aspect: aspect, fovy: fov, near: near, far: far)

        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = .init(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        
        makeDepthTexture()
        passDescriptor.depthAttachment.texture = self.depthTexture
        passDescriptor.depthAttachment.clearDepth = 1.0
        passDescriptor.depthAttachment.loadAction = .clear
        passDescriptor.depthAttachment.storeAction = .dontCare

        if commandQueue == nil {
            commandQueue = device?.makeCommandQueue()
        }
        let commandBuffer = commandQueue!.makeCommandBuffer()
        let semaphore = inFlightSemaphore
        commandBuffer?.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
            semaphore.signal()
        }
        
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: passDescriptor)
        encoder?.setRenderPipelineState(self.pipeline!)
        encoder?.setDepthStencilState(self.depthStencilState)
        encoder?.setFrontFacing(.counterClockwise)
        encoder?.setCullMode(.back)

        encoder?.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)

        uniforms[0].modelViewProjectionMatrix = matrix_multiply(matrix_multiply(projectionMatrix, viewMatrix), modelMatrix)
        encoder?.setVertexBuffer(uniformBuffer, offset:uniformBufferOffset, index: 1)
//        var uniforms = GUniforms(modelViewProjectionMatrix: matrix_multiply(matrix_multiply(projectionMatrix, viewMatrix), modelMatrix))
//        encoder?.setVertexBytes(&uniforms,
//                                       length: MemoryLayout<GUniforms>.stride,
//                                       index: 1)

        encoder?.drawIndexedPrimitives(type: .triangle, indexCount: self.indexBuffer!.length / MemoryLayout<UInt16>.size, indexType: .uint16, indexBuffer: self.indexBuffer!, indexBufferOffset: 0)
//        encoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}

extension GMetalView {
    func matrix_float4x4_translation(t:vector_float3) -> matrix_float4x4 {
        let X = vector_float4( 1, 0, 0, 0 )
        let Y = vector_float4(0, 1, 0, 0 )
        let Z = vector_float4( 0, 0, 1, 0 )
        let W = vector_float4(t.x, t.y, t.z, 1 )
        
        let mat = matrix_float4x4(columns:( X, Y, Z, W ))
        return mat
    }
    
    func matrix_float4x4_uniform_scale(scale:Float) -> matrix_float4x4 {
        let X = vector_float4( scale, 0, 0, 0 )
        let Y = vector_float4( 0, scale, 0, 0 )
        let Z = vector_float4( 0, 0, scale, 0 )
        let W = vector_float4( 0, 0, 0, 1 )
        
        let mat = matrix_float4x4(columns:( X, Y, Z, W ))
        return mat
    }
    
    func matrix_float4x4_rotation(axis:vector_float3, angle:Float) -> matrix_float4x4 {
        let c = cos(angle)
        let s = sin(angle)
        
        var X = vector_float4()
        X.x = axis.x * axis.x + (1 - axis.x * axis.x) * c;
        X.y = axis.x * axis.y * (1 - c) - axis.z * s;
        X.z = axis.x * axis.z * (1 - c) + axis.y * s;
        X.w = 0.0;
        
        var Y = vector_float4()
        Y.x = axis.x * axis.y * (1 - c) + axis.z * s;
        Y.y = axis.y * axis.y + (1 - axis.y * axis.y) * c;
        Y.z = axis.y * axis.z * (1 - c) - axis.x * s;
        Y.w = 0.0;
        
        var Z = vector_float4()
        Z.x = axis.x * axis.z * (1 - c) - axis.y * s;
        Z.y = axis.y * axis.z * (1 - c) + axis.x * s;
        Z.z = axis.z * axis.z + (1 - axis.z * axis.z) * c;
        Z.w = 0.0;
        
        var W = vector_float4()
        W.x = 0.0;
        W.y = 0.0;
        W.z = 0.0;
        W.w = 1.0;
        
        let mat = matrix_float4x4(columns:( X, Y, Z, W ))
        return mat
    }
    
    func matrix_float4x4_perspective(aspect:Float, fovy:Float, near:Float, far:Float) -> matrix_float4x4 {
        let yScale = 1 / tan(fovy * 0.5);
        let xScale = yScale / aspect;
        let zRange = far - near;
        let zScale = -(far + near) / zRange;
        let wzScale = -2 * far * near / zRange;
        
        let P = vector_float4( xScale, 0, 0, 0 )
        let Q = vector_float4( 0, yScale, 0, 0 )
        let R = vector_float4( 0, 0, zScale, -1 )
        let S = vector_float4( 0, 0, wzScale, 0 )
        
        let mat = matrix_float4x4(columns:( P, Q, R, S ))
        return mat
    }
}
