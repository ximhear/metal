//
//  GMetalView.swift
//  metal02
//
//  Created by LEE CHUL HYUN on 4/21/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import UIKit
import Metal
import simd
import QuartzCore
import MetalKit

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
    var vertices: UnsafeMutablePointer<GVertex>

    var textures: [MTLTexture]?
    var samplerState: MTLSamplerState?

    required init?(coder aDecoder: NSCoder) {
 
        device = MTLCreateSystemDefaultDevice()

        let uniformBufferSize = alignedUniformsSize * maxBuffersInFlight
        
        guard let buffer = self.device?.makeBuffer(length:uniformBufferSize, options:[MTLResourceOptions.storageModeShared]) else { return nil }
        uniformBuffer = buffer
        
        self.uniformBuffer.label = "UniformBuffer"
        
        uniforms = UnsafeMutableRawPointer(uniformBuffer.contents()).bindMemory(to:GUniforms.self, capacity:1)

        vertexBuffer = device?.makeBuffer(length: 3 * MemoryLayout<GVertex>.stride * 6, options: .cpuCacheModeWriteCombined)
        vertices = UnsafeMutableRawPointer(vertexBuffer!.contents()).bindMemory(to:GVertex.self, capacity:3)

        super.init(coder: aDecoder)
        
        makeDevice()

        textures = [MTLTexture].init()
        var image = generateCircularSector(radius: UIScreen.main.bounds.size.width / 2.0, count: 3, borderColor: UIColor.blue, fillColor: UIColor.yellow)
        var texture = getTexture(device: device!, cgImage: image!.cgImage!)
        textures?.append(texture!)

        texture = getTexture(device: device!, imageName: "aaa.png")
        textures?.append(texture!)

        image = generateCircularSector(radius: UIScreen.main.bounds.size.width / 2.0, count: 3, borderColor: UIColor.cyan, fillColor: UIColor.magenta)
        texture = getTexture(device: device!, cgImage: image!.cgImage!)
        textures?.append(texture!)

        image = generateCircularSector(radius: UIScreen.main.bounds.size.width / 2.0, count: 3, borderColor: UIColor.black, fillColor: UIColor.green)
        texture = getTexture(device: device!, cgImage: image!.cgImage!)
        textures?.append(texture!)

        image = generateCircularSector(radius: UIScreen.main.bounds.size.width / 2.0, count: 3, borderColor: UIColor.magenta, fillColor: UIColor.red)
        texture = getTexture(device: device!, cgImage: image!.cgImage!)
        textures?.append(texture!)
        
        image = generateCircularSector(radius: UIScreen.main.bounds.size.width / 2.0, count: 3, borderColor: UIColor.brown, fillColor: UIColor.orange)
        texture = getTexture(device: device!, cgImage: image!.cgImage!)
        textures?.append(texture!)
        
        GZLog(texture)
        buildSamplerState()
        makeBuffers()
        makePipeline()
        
    }
    
    func makeDevice() {
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
    }

    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.normalizedCoordinates = true
        samplerState = self.device!.makeSamplerState(descriptor: descriptor)
    }

    let indices: [UInt16] = [
        0, 1, 2
    ]
    
    func makeBuffers() {
        indexBuffer = device?.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.stride, options: .cpuCacheModeWriteCombined)
    }
    
    func makePipeline() {
        let library = device?.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertex_main")
        let fragmentFunc = library?.makeFunction(name: "textured_fragment")
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
//        elapsedTime += duration
//        self.rotationX += duration * Float(Double.pi / 2);
//        self.rotationY += duration * Float(Double.pi / 3);
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
        
        let cameraTranslation = vector_float3(0, 0, 0)
        let viewMatrix = matrix_float4x4_translation(t: cameraTranslation)
        
        let drawableSize = self.metalLayer.drawableSize
        var ratio: Float = Float(drawableSize.width / drawableSize.height)
        let projectionMatrix = matrix_float4x4_ortho(left: -2, right: 2, bottom: -2 / ratio, top: 2 / ratio, near: -1, far: 1)

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
        encoder?.setFragmentSamplerState(samplerState, index: 0)
        encoder?.setFrontFacing(.counterClockwise)
        encoder?.setCullMode(.back)

        uniforms = UnsafeMutableRawPointer(uniformBuffer.contents() + uniformBufferOffset).bindMemory(to:GUniforms.self, capacity:1)

        encoder?.setFragmentTexture(self.textures![0], index: 0)
        drawPie(encoder: encoder, index: 0, scaleFactor: scaleFactor, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        encoder?.setFragmentTexture(self.textures![1], index: 0)
        drawPie(encoder: encoder, index: 1, scaleFactor: scaleFactor, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        encoder?.setFragmentTexture(self.textures![2], index: 0)
        drawPie(encoder: encoder, index: 2, scaleFactor: scaleFactor, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        encoder?.setFragmentTexture(self.textures![3], index: 0)
        drawPie(encoder: encoder, index: 3, scaleFactor: scaleFactor, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        encoder?.setFragmentTexture(self.textures![4], index: 0)
        drawPie(encoder: encoder, index: 4, scaleFactor: scaleFactor, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)
        encoder?.setFragmentTexture(self.textures![5], index: 0)
        drawPie(encoder: encoder, index: 5, scaleFactor: scaleFactor, projectionMatrix: projectionMatrix, viewMatrix: viewMatrix)

        
        encoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
    
    func drawPie(encoder: MTLRenderCommandEncoder?, index: Int, scaleFactor: Float, projectionMatrix: matrix_float4x4, viewMatrix: matrix_float4x4) {
        let zAxis = vector_float3(0, 0, 1)
        var zRot = matrix_float4x4_rotation(axis: zAxis, angle: 0)
        let scale = matrix_float4x4_uniform_scale(scale: scaleFactor)
        var modelMatrix = matrix_multiply(zRot, scale)
        
        zRot = matrix_float4x4_rotation(axis: zAxis, angle: Float.pi * 2 / 6 * Float(index))
        modelMatrix = matrix_multiply(zRot, scale)
        uniforms[0].modelViewProjectionMatrix = matrix_multiply(matrix_multiply(projectionMatrix, viewMatrix), modelMatrix)
        let m = matrix_multiply(matrix_multiply(projectionMatrix, viewMatrix), modelMatrix)
        vertices = UnsafeMutableRawPointer(vertexBuffer!.contents() + 3 * MemoryLayout<GVertex>.stride * index).bindMemory(to:GVertex.self, capacity:3)
        vertices[0] = GVertex.init(position: .init(0, 0, 0, 1), color: .init(0, 1, 1, 1), texture:float2(0.5 ,1), col0: vector_float4(), col1: vector_float4(), col2: vector_float4(), col3: vector_float4())
        vertices[1] = GVertex.init(position: .init(1, sqrt(3), 0, 1), color: .init(1, 0, 1, 1), texture:float2(1, 0), col0: vector_float4(), col1: vector_float4(), col2: vector_float4(), col3: vector_float4())
        vertices[2] = GVertex.init(position: .init(-1, sqrt(3), 0, 1), color: .init(0, 0, 1, 1), texture:float2(0, 0), col0: vector_float4(), col1: vector_float4(), col2: vector_float4(), col3: vector_float4())
        self.vertices[0].col0 = m.columns.0;
        self.vertices[0].col1 = m.columns.1;
        self.vertices[0].col2 = m.columns.2;
        self.vertices[0].col3 = m.columns.3;
        self.vertices[1].col0 = m.columns.0;
        self.vertices[1].col1 = m.columns.1;
        self.vertices[1].col2 = m.columns.2;
        self.vertices[1].col3 = m.columns.3;
        self.vertices[2].col0 = m.columns.0;
        self.vertices[2].col1 = m.columns.1;
        self.vertices[2].col2 = m.columns.2;
        self.vertices[2].col3 = m.columns.3;
        encoder?.setVertexBuffer(self.vertexBuffer, offset: 3 * MemoryLayout<GVertex>.stride * index, index: 0)
        encoder?.setVertexBuffer(uniformBuffer, offset:uniformBufferOffset, index: 1)
        encoder?.drawIndexedPrimitives(type: .triangle, indexCount: self.indexBuffer!.length / MemoryLayout<UInt16>.size, indexType: .uint16, indexBuffer: self.indexBuffer!, indexBufferOffset: 0)
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
}

extension GMetalView {
    
    func getTexture(device: MTLDevice, imageName: String) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        var texture: MTLTexture? = nil
        let textureLoaderOptions: [MTKTextureLoader.Option : Any]
        if #available(iOS 10.0, *) {
            let origin = MTKTextureLoader.Origin.topLeft
            textureLoaderOptions = [MTKTextureLoader.Option.origin: origin,
                                    MTKTextureLoader.Option.generateMipmaps:true]
        } else {
            textureLoaderOptions = [:]
        }
        
        if let textureURL = Bundle.main.url(forResource: imageName, withExtension: nil) {
            do {
                texture = try textureLoader.newTexture(URL: textureURL,
                                                       options: textureLoaderOptions)
            } catch {
                GZLog("texture not created")
            }
        }
        return texture
    }
    
    func getTexture(device: MTLDevice, cgImage: CGImage) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        var texture: MTLTexture? = nil
        let textureLoaderOptions: [MTKTextureLoader.Option : Any]
        if #available(iOS 10.0, *) {
            let origin = MTKTextureLoader.Origin.topLeft
            textureLoaderOptions = [MTKTextureLoader.Option.origin: origin,
                                    MTKTextureLoader.Option.generateMipmaps:true]
        } else {
            textureLoaderOptions = [:]
        }
        
        do {
            texture = try textureLoader.newTexture(cgImage: cgImage,
                                                   options: textureLoaderOptions)
//            GZLog(texture)
        } catch {
            GZLog("texture not created")
        }
        return texture
    }
    
    // generateCircularSector(radius: UIScreen.main.bounds.size.width / 2.0, count: UInt(slider.value), backgroundColor: UIColor.yellow)
    func generateCircularSector(radius: CGFloat, count: UInt, borderColor: UIColor, fillColor: UIColor) -> UIImage? {
        guard count > 0 else {
            return nil
        }
        let angle: CGFloat = CGFloat.pi / CGFloat(count)
        let lineWidth: CGFloat = 10
        var imageSize = CGSize.zero
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        var startAngle: CGFloat = 0
        var endAngle: CGFloat = 0
        var center = CGPoint.zero
        
        var startAngle1: CGFloat = 0
        var endAngle1: CGFloat = 0
        var center1 = CGPoint.zero
        
        if angle >= CGFloat.pi {
            width = radius * 2
            height = sin((angle - CGFloat.pi)/2.0) * radius + radius
            
            startAngle = (angle - CGFloat.pi) / 2.0
            endAngle = startAngle - angle
            
            center = CGPoint.init(x: width / 2, y: radius)
            
            var theta: CGFloat = (CGFloat.pi * 2 - angle) / 2
            var m: CGFloat = tan(CGFloat.pi / 2 - theta)
            var b: CGFloat = lineWidth / 2 / sin(theta)
            var p: CGFloat = radius - lineWidth
            var x: CGFloat = (-m * b - sqrt(m*m*b*b - (m*m+1)*(b*b-p*p)))/(m*m + 1)
            var y: CGFloat = m * x + b
            
            var theta1 = atan( y / x)
            var newAnagle = CGFloat.pi + 2 * theta1
            startAngle1 = (newAnagle - CGFloat.pi) / 2.0
            endAngle1 = startAngle1 - newAnagle
            
            center1 = CGPoint.init(x: width / 2, y: center.y - lineWidth / 2 / sin(theta))
        }
        else {
            width = radius * tan(angle / 2)  * 2
            height = radius
            
            startAngle = -(CGFloat.pi - angle) / 2.0
            endAngle = startAngle - angle
            
            center = CGPoint.init(x: width / 2, y: height)
            
            var theta: CGFloat =  angle / 2
            var m: CGFloat = tan(CGFloat.pi / 2 - theta)
            var b: CGFloat = lineWidth / 2 / sin(theta)
            var p: CGFloat = radius - lineWidth
            var x: CGFloat = (-m * b + sqrt(m*m*b*b - (m*m+1)*(b*b-p*p)))/(m*m + 1)
            var y: CGFloat = m * x + b
            
            var theta1 = atan( y / x)
            var newAnagle = CGFloat.pi - 2 * theta1
            startAngle1 = -(CGFloat.pi - newAnagle) / 2.0
            endAngle1 = startAngle1 - newAnagle
            
            center1 = CGPoint.init(x: width / 2, y: center.y - lineWidth / 2 / sin(theta))
        }
//        imageSize = CGSize.init(width: (Int(width + 1) / 2) * 2 , height: (Int(height + 1) / 2) * 2)
        imageSize = CGSize.init(width: width , height: height)

//        imageSize = CGSize.init(width: 64, height: 64)
        UIGraphicsBeginImageContextWithOptions(imageSize, true, 0)
        let context = UIGraphicsGetCurrentContext()!
        
        UIColor.green.setFill()
        context.fill(CGRect.init(x: 0, y: 0, width: imageSize.width, height: imageSize.height))

        UIColor.green.setFill()
        context.fill(CGRect.init(x: 0, y: 10, width: imageSize.width, height: imageSize.height-10))

        context.move(to: center)
        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        context.addLine(to: center)

        borderColor.setFill()
        context.fillPath()

        context.move(to: center1)
        context.addArc(center: center, radius: radius - lineWidth, startAngle: startAngle1, endAngle: endAngle1, clockwise: true)
        context.addLine(to: center1)
        
//        context.addRect(CGRect.init(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        fillColor.setFill()
        context.fillPath()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}

