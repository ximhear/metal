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
    var pipeline: MTLRenderPipelineState?
    var displayLink: CADisplayLink?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        makeDevice()
        makeBuffers()
        makePipeline()
    }
    
    func makeDevice() {
        device = MTLCreateSystemDefaultDevice()
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
    }
    
    let vertices: [GVertex] = [
        GVertex.init(position: .init(0, 0.5, 0, 1), color: .init(1, 0, 0, 1)),
        GVertex.init(position: .init(-0.5, -0.5, 0, 1), color: .init(0, 1, 0, 1)),
        GVertex.init(position: .init(0.5, -0.5, 0, 1), color: .init(0, 0, 1, 1))
    ]
    func makeBuffers() {
        vertexBuffer = device?.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<GVertex>.stride, options: .cpuCacheModeWriteCombined)
    }
    
    func makePipeline() {
        let library = device?.makeDefaultLibrary()
        let vertexFunc = library?.makeFunction(name: "vertex_main")
        let fragmentFunc = library?.makeFunction(name: "fragment_main")
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunc
        descriptor.fragmentFunction = fragmentFunc
        descriptor.colorAttachments[0].pixelFormat = self.metalLayer.pixelFormat
        pipeline = try? device!.makeRenderPipelineState(descriptor: descriptor)
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
        self.redraw()
    }
    
    func redraw() {
        guard let drawable = self.metalLayer.nextDrawable() else {
            return
        }
        let texture = drawable.texture
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = .init(red: 0.25, green: 0.25, blue: 0.25, alpha: 1)
        
        if commandQueue == nil {
            commandQueue = device?.makeCommandQueue()
        }
        let commandBuffer = commandQueue!.makeCommandBuffer()
        let encoder = commandBuffer?.makeRenderCommandEncoder(descriptor: passDescriptor)
        encoder?.setRenderPipelineState(self.pipeline!)
        encoder?.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        encoder?.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}
