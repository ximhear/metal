//
//  GameViewController.swift
//  cube03
//
//  Created by C.H Lee on 21/06/2017.
//  Copyright © 2017 C.H Lee. All rights reserved.
//

import UIKit
import Metal
import MetalKit

struct MBEVertex {
    var position : vector_float4
    var color : vector_float4
    var texture : float2 = float2(0, 0)
}

struct MBEUniforms {
    var modelViewProjectionMatrix : matrix_float4x4
}


let MaxBuffers = 3
class GameViewController:UIViewController, MTKViewDelegate {
    
    var device : MTLDevice?
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
    
    let inflightSemaphore = DispatchSemaphore(value: MaxBuffers)
    
    
    var metalView : MTKView {
        get {
            return self.view as! MTKView
        }
    }
    
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        device = MTLCreateSystemDefaultDevice()
        guard device != nil else { // Fallback to a blank UIView, an application could also fallback to OpenGL ES here.
            print("Metal is not supported on this device")
            self.view = UIView(frame: self.view.frame)
            return
        }

        // setup view properties
        let view = self.view as! MTKView
        view.device = device
        view.delegate = self
        
        loadAssets()
    }
    
    func loadAssets() {
        
        buildSamplerState()
        makeTexture()
        //        makeBuffers()
        makePipeline()
        addRectangles()
        makeDepthTexture(size:self.metalView.drawableSize)
    }
    
    private func buildSamplerState() {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        samplerState = self.device!.makeSamplerState(descriptor: descriptor)
    }
    
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
    
    func makeDepthTexture(size: CGSize) {
        let drawableSize = size
        
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
        self.texture2 = getTexture(device: self.device!, imageName: "ccc.png")
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

    func draw(in view: MTKView) {
        
        // use semaphore to encode 3 frames ahead
        let _ = inflightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        let duration : Float = 1.0 / 60.0
        elapsedTime += duration
        self.rotationX += duration * Float(Double.pi / 2);
        self.rotationY += duration * Float(Double.pi / 3);
        
        let drawable = self.metalView.currentDrawable
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
        
        let drawableSize = self.metalView.drawableSize
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
        
//        makeDepthTexture(size: self.metalView.drawableSize)
        passDescriptor.depthAttachment.texture = self.depthTexture
        passDescriptor.depthAttachment.clearDepth = 1.0
        passDescriptor.depthAttachment.loadAction = .clear
        passDescriptor.depthAttachment.storeAction = .dontCare
        
        let commandBuffer = commandQueue?.makeCommandBuffer()
        commandBuffer?.addCompletedHandler{ [weak self] commandBuffer in
            if let strongSelf = self {
                strongSelf.inflightSemaphore.signal()
            }
            return
        }
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
    
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        makeDepthTexture(size:size)
    }
}
