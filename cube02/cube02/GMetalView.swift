//
//  GMetalView.swift
//  cube02
//
//  Created by LEE CHUL HYUN on 6/5/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import UIKit
import Metal
import QuartzCore
import simd
import MetalKit

struct MBEVertex {
    var position : vector_float4
    var color : vector_float4
    var texture : float2 = float2(0, 0)
}

struct MBEUniforms {
    var modelViewProjectionMatrix : matrix_float4x4
}

class GMetalView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    var device : MTLDevice?
//    var vertexBuffer: MTLBuffer?
//    var indexBuffer: MTLBuffer?
    var pipeline : MTLRenderPipelineState?
    var depthStencilState : MTLDepthStencilState?
    var depthTexture : MTLTexture?
    var commandQueue : MTLCommandQueue?
    var displayLink : CADisplayLink?
    var elapsedTime : Float = 0
    var rotationX : Float = 0
    var rotationY : Float = 0
    var texture1: MTLTexture?
    var texture2: MTLTexture?
    var samplerState: MTLSamplerState?
    
    var renderables : [Renderable] = []
    
    override class var layerClass: Swift.AnyClass {
        return CAMetalLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        
        self.makeDevice()
        buildSamplerState()
        makeTexture()
//        makeBuffers()
        makePipeline()
        addRectangles()
    }
    
    deinit {
        GZLog()
        displayLink?.invalidate()
    }
    
    var metalLayer : CAMetalLayer? {
        return self.layer as? CAMetalLayer
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if self.superview != nil {
            if displayLink == nil {
                displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
                displayLink?.add(to: RunLoop.main, forMode: .commonModes)
            }
        }
        else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    @objc func displayLinkDidFire() {
        let duration : Float = 1.0 / 60.0
        elapsedTime += duration
        self.rotationX += duration * Float(Double.pi / 2);
        self.rotationY += duration * Float(Double.pi / 3);
        redraw()
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        samplerState = self.device!.makeSamplerState(descriptor: descriptor)
    }
    
    func redraw() {
        
        let drawable = self.metalLayer?.nextDrawable()
        let texture = drawable?.texture
        
        let scaleFactor = sin(2.5 * self.elapsedTime) * 0.75 + 1.0
        let xAxis = vector_float3(1, 0, 0)
        let yAxis = vector_float3(0, 1, 0)
        let xRot = matrix_float4x4_rotation(axis: xAxis, angle: rotationX)
        let yRot = matrix_float4x4_rotation(axis: yAxis, angle: rotationY)
        let scale = matrix_float4x4_uniform_scale(scale: scaleFactor)
        let modelMatrix = matrix_multiply(matrix_multiply(xRot, yRot), scale)
        
        let cameraTranslation = vector_float3(0, 0, -5)
        let viewMatrix = matrix_float4x4_translation(t: cameraTranslation)
        
        let drawableSize = self.metalLayer!.drawableSize
        let aspect = Float(drawableSize.width / drawableSize.height)
        let fov = Float(2 * Double.pi) / 5
        let near : Float = 1
        let far : Float = 100
        let projectionMatrix = matrix_float4x4_perspective(aspect: aspect, fovy: fov, near: near, far: far)
        
        
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 0, alpha: 1)
        
//        makeDepthTexture()
        passDescriptor.depthAttachment.texture = self.depthTexture
        passDescriptor.depthAttachment.clearDepth = 1.0
        passDescriptor.depthAttachment.loadAction = .clear
        passDescriptor.depthAttachment.storeAction = .dontCare
        
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: passDescriptor)
        commandEncoder?.setRenderPipelineState(self.pipeline!)
        commandEncoder?.setDepthStencilState(self.depthStencilState)
        commandEncoder?.setFragmentSamplerState(samplerState, index: 0)
        commandEncoder?.setFrontFacing(.counterClockwise)
        commandEncoder?.setCullMode(.back)
        
        var uniforms = MBEUniforms(modelViewProjectionMatrix: matrix_multiply(matrix_multiply(projectionMatrix, viewMatrix), modelMatrix))
        commandEncoder?.setVertexBytes(&uniforms,
                                       length: MemoryLayout<MBEUniforms>.stride,
                                       index: 1)
        for renderable in self.renderables {
            
            renderable.redraw(commandEncoder: commandEncoder!)
        }
        commandEncoder?.endEncoding()
        commandBuffer?.present(drawable!)
        commandBuffer?.commit()
    }
    
    func makeDevice() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.metalLayer?.device = self.device
        self.metalLayer?.pixelFormat = .bgra8Unorm
    }
    
    /*
    func makeBuffers() {
        
        var vertices1 = [
            MBEVertex(position: vector_float4(-1, 1, 1, 1), color: vector_float4(0, 1, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, -1, 1, 1), color: vector_float4(0, 0, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, -1, 1, 1), color: vector_float4(1, 0, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, 1, 1, 1), color: vector_float4(1, 1, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, 1, -1, 1), color: vector_float4(0, 1, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, -1, -1, 1), color: vector_float4(0, 0, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, -1, -1, 1), color: vector_float4(1, 0, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, 1, -1, 1), color: vector_float4(1, 1, 0, 1), texture:float2(0,0))
        ]
        
        var vertices : [MBEVertex] = []
        
        let indices2 : [(Int, Int, Int, Int)] = [
            (3, 2, 6, 7),
            (4, 5, 1, 0),
            (4, 0, 3, 7),
            (1, 5, 6, 2),
            (0, 1, 2, 3),
            (7, 6, 5, 4)
        ]
        
        let indices1 : [UInt16] = [
            3, 2, 6, 6, 7, 3,
            4, 5, 1, 1, 0, 4,
            4, 0, 3, 3, 7, 4,
            1, 5, 6, 6, 2, 1,
            0, 1, 2, 2, 3, 0,
            7, 6, 5, 5, 4, 7
        ]
        
        var indices : [UInt16] = []
        for (index, (a, b, c, d)) in indices2.enumerated() {
            var vertex0 = vertices1[a]
            var vertex1 = vertices1[b]
            var vertex2 = vertices1[c]
            var vertex3 = vertices1[d]
            
            vertex0.texture = float2(0,0)
            vertex1.texture = float2(0,1)
            vertex2.texture = float2(1,1)
            vertex3.texture = float2(1,0)
            vertices.append(contentsOf: [vertex0, vertex1, vertex2, vertex3])
            let offset = UInt16(index) * 4
            indices.append(contentsOf: [0, 1, 2, 2, 3, 0].map({ (a) -> UInt16 in
                return a + offset
            }))
        }
        
        self.vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<MBEVertex>.stride, options: [])
        self.indexBuffer = device?.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt16>.size, options: [])
    }
 */
    
    func addRectangles() {
        
        var vertices1 = [
            MBEVertex(position: vector_float4(-1, 1, 1, 1), color: vector_float4(0, 1, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, -1, 1, 1), color: vector_float4(0, 0, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, -1, 1, 1), color: vector_float4(1, 0, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, 1, 1, 1), color: vector_float4(1, 1, 1, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, 1, -1, 1), color: vector_float4(0, 1, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(-1, -1, -1, 1), color: vector_float4(0, 0, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, -1, -1, 1), color: vector_float4(1, 0, 0, 1), texture:float2(0,0)),
            MBEVertex(position: vector_float4(1, 1, -1, 1), color: vector_float4(1, 1, 0, 1), texture:float2(0,0))
        ]
        
        var vertices : [MBEVertex] = []
        
        let indices2 : [(Int, Int, Int, Int)] = [
            (3, 2, 6, 7),
            (4, 5, 1, 0),
            (4, 0, 3, 7),
            (1, 5, 6, 2),
            (0, 1, 2, 3),
            (7, 6, 5, 4)
        ]
        
        for (index, (a, b, c, d)) in indices2.enumerated() {
            let vertex0 = vertices1[a]
            let vertex1 = vertices1[b]
            let vertex2 = vertices1[c]
            let vertex3 = vertices1[d]
            let rect = Rectangle(device: self.device!, texture: index%2 == 0 ? self.texture1! : self.texture2!, vertices: [vertex0, vertex1, vertex2, vertex3])
            self.renderables.append(rect)
        }
    }
    
    func makePipeline() {
        let library = device?.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertex_main")
//        let fragmentFunc = library?.makeFunction(name: "fragment_main")
        let fragmentFunc = library?.makeFunction(name: "textured_fragment")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        self.depthStencilState = self.device?.makeDepthStencilState(descriptor: depthStencilDescriptor)
        
        self.pipeline = try? self.device!.makeRenderPipelineState(descriptor: pipelineDescriptor)
        
        self.commandQueue = self.device?.makeCommandQueue()
    }
    
    func makeDepthTexture() {
        let drawableSize = self.metalLayer!.drawableSize
        
        if let texture = self.depthTexture {
            if Int(drawableSize.width) == texture.width && Int(drawableSize.height) == texture.height {
                return
            }
        }
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: Int(drawableSize.width), height: Int(drawableSize.height), mipmapped: false)
        desc.usage = .renderTarget
        depthTexture = self.device?.makeTexture(descriptor: desc)
    }
    
    func makeTexture() {
        self.texture1 = getTexture(device: self.device!, imageName: "bbb.png")
//        self.texture2 = getTexture(device: self.device!, imageName: "ccc.png")
        let image = generateCircularSector(radius: UIScreen.main.bounds.size.width / 2.0, count: 3, backgroundColor: UIColor.yellow)
        self.texture2 = getTexture(device: device!, cgImage: image!.cgImage!)
    }
    
    
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
    
    override var frame: CGRect {
        get {
            return super.frame
        }
        set {
            super.frame = newValue
            var scale = UIScreen.main.scale
            if let w = self.window {
                scale = w.screen.scale
            }
            var drawableSize = self.bounds.size
            drawableSize.width *= scale
            drawableSize.height *= scale
            
            self.metalLayer?.drawableSize = drawableSize
            
            self.makeDepthTexture()
        }
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
    
}

extension GMetalView : AppProtocol {
    
    func applicationWillResignActive() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func applicationDidBecomeActive() {
        
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            displayLink?.add(to: RunLoop.main, forMode: .commonModes)
        }
    }
}

extension GMetalView {

    func generateCircularSector(radius: CGFloat, count: UInt, backgroundColor: UIColor) -> UIImage? {
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
            width = radius * sin(angle / 2) * 2
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
        
        UIColor.yellow.setFill()
        context.fill(CGRect.init(x: 0, y: 10, width: imageSize.width, height: imageSize.height-10))
        
        context.move(to: center)
        context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        context.addLine(to: center)
        
        backgroundColor.setFill()
        context.fillPath()
        
        context.move(to: center1)
        context.addArc(center: center, radius: radius - lineWidth, startAngle: startAngle1, endAngle: endAngle1, clockwise: true)
        context.addLine(to: center1)
        
        //        context.addRect(CGRect.init(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        UIColor.red.setFill()
        context.fillPath()
        
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }

    func getTexture(device: MTLDevice, cgImage: CGImage) -> MTLTexture? {
        let textureLoader = MTKTextureLoader(device: device)
        var texture: MTLTexture? = nil
        let textureLoaderOptions: [MTKTextureLoader.Option : Any]
        if #available(iOS 10.0, *) {
            let origin = MTKTextureLoader.Origin.topLeft
            textureLoaderOptions = [MTKTextureLoader.Option.origin: origin,
                                    MTKTextureLoader.Option.generateMipmaps:false]
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

}
