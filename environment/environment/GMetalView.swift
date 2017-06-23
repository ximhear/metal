//
//  GMetalView.swift
//  environment
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
    var normal : vector_float4
}

struct GMatrix {
    var matrix1 : float4x4
    var matrix2 : float4x4
    var matrix3 : float4x4
    var matrix4 : float4x4
    var vector1 : float2
}


class GMetalView: UIView {
    
    struct MBEUniforms {
        var modelMatrix : matrix_float4x4
        var projectionMatrix : matrix_float4x4
        var modelViewProjectionMatrix : matrix_float4x4
        var normalMatrix : matrix_float4x4
        var worldCameraPosition : vector_float4
    }
    
    
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
    var texture: MTLTexture?
    var samplerState: MTLSamplerState?
    
    var renderables : [Renderable] = []
    var uniformBuffer : MTLBuffer?
    
    override class var layerClass: Swift.AnyClass {
        return CAMetalLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        
        self.makeDevice()
        buildSamplerState()
        makeTexture()
        makeBuffers()
        makePipeline()
        addRectangles()
    }
    
    deinit {
        SBLog.debug()
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
        redraw()
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        samplerState = self.device!.makeSamplerState(descriptor: descriptor)
    }
    
    func redraw() {
        
        let depthDescriptor = MTLDepthStencilDescriptor();
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = false
        let depthState = self.device!.makeDepthStencilState(descriptor: depthDescriptor)
        
        let drawable = self.metalLayer?.nextDrawable()
        let texture = drawable?.texture
        
        let drawableSize = self.metalLayer!.drawableSize
        let aspectRatio = Float(drawableSize.width / drawableSize.height)
        let near : Float = 0.1
        let far : Float = 100
        let verticalFOV : Float = (aspectRatio > 1) ? 60 : 90
        
        let projectionMatrix = GMetalView.matrix_float4x4_perspective(aspect: aspectRatio, fovy: verticalFOV * Float(Double.pi) / 180.0, near: near, far: far)
        let modelMatrix = GMetalView.matrix_float4x4_identity()
        let viewMatrix = GMetalView.matrix_float4x4_identity()
        let cameraTranslation = vector_float4(0, 0, -4, 1)
        let worldCameraPosition = matrix_multiply(simd_inverse(GMetalView.matrix_float4x4_identity()), -cameraTranslation)
        
        
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 0, alpha: 1)
        
        makeDepthTexture()
        passDescriptor.depthAttachment.texture = self.depthTexture
        passDescriptor.depthAttachment.clearDepth = 1.0
        passDescriptor.depthAttachment.loadAction = .clear
        passDescriptor.depthAttachment.storeAction = .dontCare
        
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: passDescriptor)
        commandEncoder?.setRenderPipelineState(self.pipeline!)
        commandEncoder?.setDepthStencilState(depthState)
        commandEncoder?.setFragmentSamplerState(samplerState, index: 0)
        commandEncoder?.setFragmentTexture(self.texture, index: 0)
        
        var uniforms = MBEUniforms(modelMatrix: matrix_identity_float4x4, projectionMatrix: matrix_identity_float4x4, modelViewProjectionMatrix: matrix_identity_float4x4, normalMatrix: matrix_identity_float4x4, worldCameraPosition: vector_float4(1))
        uniforms.modelMatrix = modelMatrix
        uniforms.projectionMatrix = projectionMatrix
        uniforms.normalMatrix = simd_transpose(simd_inverse(uniforms.modelMatrix))
        uniforms.modelViewProjectionMatrix = matrix_multiply(projectionMatrix, matrix_multiply(viewMatrix, modelMatrix))
        uniforms.worldCameraPosition = worldCameraPosition
        
//        var contents = self.uniformBuffer?.contents()
//        withUnsafePointer(to: &uniforms, { (raw) -> Void in
//            memcpy(contents, raw, MemoryLayout<MBEUniforms>.size)
//        })
//        commandEncoder?.setVertexBuffer(self.uniformBuffer, offset: 0, index: 1)
        
//        var m = GMatrix()
//        m.matrix1 = matrix_
//        commandEncoder?.setVertexBytes(&m,
//                                       length: MemoryLayout<GMatrix>.stride,
//                                       index: 1)
        
        commandEncoder?.setVertexBytes(&uniforms,
                                       length: MemoryLayout<MBEUniforms>.stride,
                                       index: 1)
        
        for renderable in self.renderables {
            renderable.redraw(commandEncoder: commandEncoder!)
        }
        commandEncoder?.setFrontFacing(.counterClockwise)
        commandEncoder?.setCullMode(.back)
        
        commandEncoder?.endEncoding()
        commandBuffer?.present(drawable!)
        commandBuffer?.commit()
    }
    
    func makeDevice() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.metalLayer?.device = self.device
        self.metalLayer?.pixelFormat = .bgra8Unorm
    }
    
    func makeBuffers() {
        
        self.uniformBuffer = self.device!.makeBuffer(length: MemoryLayout<MBEUniforms>.size, options: [])
    }
    
    func addRectangles() {
        
        let vertices = [
            // + Y
            MBEVertex(position: vector_float4(-0.5,  0.5,  0.5, 1.0), normal: vector_float4(0.0, -1.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(0.5,  0.5,  0.5, 1.0), normal: vector_float4(0.0, -1.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(0.5,  0.5, -0.5, 1.0), normal: vector_float4(0.0, -1.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(-0.5,  0.5, -0.5, 1.0), normal: vector_float4(0.0, -1.0,  0.0, 0.0)),
            // -Y
            MBEVertex(position: vector_float4(-0.5, -0.5, -0.5, 1.0), normal: vector_float4(0.0,  1.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(0.5, -0.5, -0.5, 1.0), normal: vector_float4(0.0,  1.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(0.5, -0.5,  0.5, 1.0), normal: vector_float4(0.0,  1.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(-0.5, -0.5,  0.5, 1.0), normal: vector_float4(0.0,  1.0,  0.0, 0.0)),
            // +Z
            MBEVertex(position: vector_float4(-0.5, -0.5,  0.5, 1.0), normal: vector_float4(0.0,  0.0, -1.0, 0.0)),
            MBEVertex(position: vector_float4(0.5, -0.5,  0.5, 1.0), normal: vector_float4(0.0,  0.0, -1.0, 0.0)),
            MBEVertex(position: vector_float4(0.5,  0.5,  0.5, 1.0), normal: vector_float4(0.0,  0.0, -1.0, 0.0)),
            MBEVertex(position: vector_float4(-0.5,  0.5,  0.5, 1.0), normal: vector_float4(0.0,  0.0, -1.0, 0.0)),
            // -Z
            MBEVertex(position: vector_float4(0.5, -0.5, -0.5, 1.0), normal: vector_float4(0.0,  0.0,  1.0, 0.0)),
            MBEVertex(position: vector_float4(-0.5, -0.5, -0.5, 1.0), normal: vector_float4(0.0,  0.0,  1.0, 0.0)),
            MBEVertex(position: vector_float4(-0.5,  0.5, -0.5, 1.0), normal: vector_float4(0.0,  0.0,  1.0, 0.0)),
            MBEVertex(position: vector_float4(0.5,  0.5, -0.5, 1.0), normal: vector_float4(0.0,  0.0,  1.0, 0.0)),
            // -X
            MBEVertex(position: vector_float4(-0.5, -0.5, -0.5, 1.0), normal: vector_float4(1.0,  0.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(-0.5, -0.5,  0.5, 1.0), normal: vector_float4(1.0,  0.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(-0.5,  0.5,  0.5, 1.0), normal: vector_float4(1.0,  0.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(-0.5,  0.5, -0.5, 1.0), normal: vector_float4(1.0,  0.0,  0.0, 0.0)),
            // +X
            MBEVertex(position: vector_float4(0.5, -0.5,  0.5, 1.0), normal: vector_float4(-1.0,  0.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(0.5, -0.5, -0.5, 1.0), normal: vector_float4(-1.0,  0.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(0.5,  0.5, -0.5, 1.0), normal: vector_float4(-1.0,  0.0,  0.0, 0.0)),
            MBEVertex(position: vector_float4(0.5,  0.5,  0.5, 1.0), normal: vector_float4(-1.0,  0.0,  0.0, 0.0)),
        ]
        
        let indices : [UInt16] = [
            0,  3,  2,  2,  1,  0,
            4,  7,  6,  6,  5,  4,
            8, 11, 10, 10,  9,  8,
            12, 15, 14, 14, 13, 12,
            16, 19, 18, 18, 17, 16,
            20, 23, 22, 22, 21, 20,
        ]
        
        let skyBox = Skybox(device: self.device!, indices: indices, vertices: vertices)
        self.renderables.append(skyBox)
    }
    
    func makePipeline() {
        let library = device?.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertex_skybox")
//        let fragmentFunc = library?.makeFunction(name: "fragment_main")
        let fragmentFunc = library?.makeFunction(name: "fragment_cube_lookup")
        
        var vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].bufferIndex = 0;
        vertexDescriptor.attributes[0].offset = 0;
        vertexDescriptor.attributes[0].format = .float4;
        
        vertexDescriptor.attributes[1].offset = MemoryLayout<vector_float4>.size
        vertexDescriptor.attributes[1].format = .float4;
        vertexDescriptor.attributes[1].bufferIndex = 0;
        
        vertexDescriptor.layouts[0].stepFunction = .perVertex;
        vertexDescriptor.layouts[0].stride = MemoryLayout<MBEVertex>.stride;
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = false
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
        self.texture = getCubeTextureImmediately(device: device!, images: ["px", "nx", "py", "ny", "pz", "nz"])
//        self.texture = getCubeTextureImmediately(device: device!, images: ["bbb", "bbb", "bbb", "bbb", "bbb", "bbb"])
    }
    
    static func matrix_float4x4_identity() -> matrix_float4x4 {
        let X = vector_float4( 1, 0, 0, 0 )
        let Y = vector_float4(0, 1, 0, 0 )
        let Z = vector_float4( 0, 0, 1, 0 )
        let W = vector_float4(0, 0, 0, 1 )
        
        let mat = matrix_float4x4(columns:( X, Y, Z, W ))
        return mat
    }
    
    static func matrix_float4x4_translation(t:vector_float3) -> matrix_float4x4 {
        let X = vector_float4( 1, 0, 0, 0 )
        let Y = vector_float4(0, 1, 0, 0 )
        let Z = vector_float4( 0, 0, 1, 0 )
        let W = vector_float4(t.x, t.y, t.z, 1 )
        
        let mat = matrix_float4x4(columns:( X, Y, Z, W ))
        return mat
    }
    
    static func matrix_float4x4_uniform_scale(scale:Float) -> matrix_float4x4 {
        let X = vector_float4( scale, 0, 0, 0 )
        let Y = vector_float4( 0, scale, 0, 0 )
        let Z = vector_float4( 0, 0, scale, 0 )
        let W = vector_float4( 0, 0, 0, 1 )
        
        let mat = matrix_float4x4(columns:( X, Y, Z, W ))
        return mat
    }
    
    static func matrix_float4x4_rotation(axis:vector_float3, angle:Float) -> matrix_float4x4 {
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
    
    static func matrix_float4x4_perspective(aspect:Float, fovy:Float, near:Float, far:Float) -> matrix_float4x4 {
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
    
    func getCubeTexture(device: MTLDevice, images:[String]) -> Void {
        
//        let image = UIImage(named: images[0])!
//        let cubeSize = image.size.width * image.scale
//        let bytePerPixel = 4
//        let bytesPerRow = bytePerPixel * Int(cubeSize)
//        let bytePerImage = bytesPerRow * Int(cubeSize)
//        
//        let textureLoaderOptions: [MTKTextureLoader.Option : Any]
//        if #available(iOS 10.0, *) {
//            let origin = MTKTextureLoader.Origin.topLeft
//            textureLoaderOptions = [MTKTextureLoader.Option.origin: origin,
//                                    MTKTextureLoader.Option.cubeLayout:MTKTextureLoader.CubeLayout.vertical]
//        } else {
//            textureLoaderOptions = [:]
//        }
//        
//        let textureLoader = MTKTextureLoader(device: device)
//        textureLoader.newTextures(withNames: images, scaleFactor: UIScreen.main.scale, bundle: Bundle.main, options: textureLoaderOptions, completionHandler: {[weak self] (textures, error) in
//            
//            SBLog.debug(textures)
//            SBLog.debug(error)
//        })
    }
    
    func getCubeTextureImmediately(device: MTLDevice, images:[String]) -> MTLTexture? {
        
        let image = UIImage(named: images[0])!
        let cubeSize = image.size.width * image.scale
        let bytePerPixel = 4
        let bytesPerRow = bytePerPixel * Int(cubeSize)
        let bytePerImage = bytesPerRow * Int(cubeSize)
        var texture : MTLTexture?
        
        let region = MTLRegionMake2D(0, 0, Int(cubeSize), Int(cubeSize))
        let textureDescriptor = MTLTextureDescriptor.textureCubeDescriptor(pixelFormat: .rgba8Unorm, size: Int(cubeSize), mipmapped: false)
        texture = device.makeTexture(descriptor: textureDescriptor)
        
        for slice in 0..<6 {
            let image = UIImage(named: images[slice])
            let data = dataForImage(image: image!)
            
            texture?.replace(region: region, mipmapLevel: 0, slice: slice, withBytes: data, bytesPerRow: bytesPerRow, bytesPerImage: bytePerImage)
        }
        return texture
    }
    
    func dataForImage(image: UIImage) -> UnsafeMutablePointer<UInt8> {
        let imageRef = image.cgImage
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let rawData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height * 4)
        let bytePerPixel = 4
        let bytesPerRow = bytePerPixel * Int(width)
        let bitsPerComponent = 8
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue + CGImageAlphaInfo.premultipliedLast.rawValue
        let context = CGContext.init(data: rawData, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        context?.draw(imageRef!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return rawData
    }
    
//    func getTexture(device: MTLDevice, imageName: String) -> MTLTexture? {
//        let textureLoader = MTKTextureLoader(device: device)
//        var texture: MTLTexture? = nil
//        let textureLoaderOptions: [MTKTextureLoader.Option : Any]
//        if #available(iOS 10.0, *) {
//            let origin = MTKTextureLoader.Origin.topLeft
//            textureLoaderOptions = [MTKTextureLoader.Option.origin: origin,
//                MTKTextureLoader.Option.generateMipmaps:true]
//        } else {
//            textureLoaderOptions = [:]
//        }
//        
//        if let textureURL = Bundle.main.url(forResource: imageName, withExtension: nil) {
//            do {
//                texture = try textureLoader.newTexture(withContentsOf: textureURL,
//                                                       options: textureLoaderOptions)
//            } catch {
//                SBLog.debug("texture not created")
//            }
//        }
//        return texture
//    }
    
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
