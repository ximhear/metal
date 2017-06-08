//
//  GMetalView.swift
//  cube01
//
//  Created by LEE CHUL HYUN on 6/5/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import UIKit
import Metal
import QuartzCore
import simd

struct MBEVertex {
    var position : vector_float4
    var color : vector_float4
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
    var vertexBuffer: MTLBuffer?
    var pipeline : MTLRenderPipelineState?
    var commandQueue : MTLCommandQueue?
    var displayLink : CADisplayLink?
    
    override class var layerClass: Swift.AnyClass {
        return CAMetalLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)

        self.makeDevice()
        makeBuffers()
        makePipeline()
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    var metalLayer : CAMetalLayer? {
        return self.layer as? CAMetalLayer
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if self.superview != nil {
            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            displayLink?.add(to: RunLoop.main, forMode: .commonModes)
        }
        else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }
    
    @objc func displayLinkDidFire() {
        redraw()
    }
    
    func redraw() {
        let drawable = self.metalLayer?.nextDrawable()
        let texture = drawable?.texture
        
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 0, alpha: 1)
        
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: passDescriptor)
        commandEncoder?.setRenderPipelineState(self.pipeline!)
        commandEncoder?.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        commandEncoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
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
        let vertices = [
            MBEVertex(position: vector_float4(0, 0.5, 0, 1), color: vector_float4(1, 0, 0, 1)),
            MBEVertex(position: vector_float4(-0.5, -0.5, 0, 1), color: vector_float4(0, 1, 0, 1)),
            MBEVertex(position: vector_float4(0.5, -0.5, 0, 1), color: vector_float4(0, 0, 1, 1))
        ]
        
        self.vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<MBEVertex>.size, options: [])
    }
    
    func makePipeline() {
        let library = device?.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertex_main")
        let fragmentFunc = library?.makeFunction(name: "fragment_main")
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunc
        pipelineDescriptor.fragmentFunction = fragmentFunc
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        self.pipeline = try? self.device!.makeRenderPipelineState(descriptor: pipelineDescriptor)
        self.commandQueue = self.device?.makeCommandQueue()
    }
}
