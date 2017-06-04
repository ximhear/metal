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

class GMetalView: UIView {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    var device : MTLDevice?

    override class var layerClass: Swift.AnyClass {
        return CAMetalLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)

        self.makeDevice()
    }
    
    var metalLayer : CAMetalLayer? {
        return self.layer as? CAMetalLayer
    }
    
    override func didMoveToWindow() {
        self.redraw()
    }
    
    func redraw() {
        let drawable = self.metalLayer?.nextDrawable()
        let texture = drawable?.texture
        
        let passDescriptor = MTLRenderPassDescriptor()
        passDescriptor.colorAttachments[0].texture = texture
        passDescriptor.colorAttachments[0].loadAction = .clear
        passDescriptor.colorAttachments[0].storeAction = .store
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 0, alpha: 1)
        
        let commandQueue = self.device?.makeCommandQueue()
        let commandBuffer = commandQueue?.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: passDescriptor)
        commandEncoder?.endEncoding()
        
        commandBuffer?.present(drawable!)
        commandBuffer?.commit()
    }
    
    func makeDevice() {
        self.device = MTLCreateSystemDefaultDevice()!
        self.metalLayer?.device = self.device
        self.metalLayer?.pixelFormat = .bgra8Unorm
    }
}
