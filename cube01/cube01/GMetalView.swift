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
    
    var metalLayer : CAMetalLayer?
    
    var device : MTLDevice

    override class var layerClass: Swift.AnyClass {
        return CAMetalLayer.self
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        self.device = MTLCreateSystemDefaultDevice()!
        
        super.init(coder: aDecoder)
        
        self.metalLayer = self.layer as? CAMetalLayer
        self.metalLayer?.device = self.device
        self.metalLayer?.pixelFormat = .bgra8Unorm
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
        passDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 0, blue: 0, alpha: 1)
        
        var commandQueue = self.device.makeCommandQueue()
        var commandBuffer = commandQueue.makeCommandBuffer()
        var commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor)
        commandEncoder.endEncoding()
        
        commandBuffer.present(drawable!)
        commandBuffer.commit()
    }
}
