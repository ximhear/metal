//
//  GImageFilter.swift
//  imageprocessing01
//
//  Created by chlee on 11/05/2018.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal

class GImageFilter: GTextureProvider, GTextureConsumer {
    
    var context: GContext
    var uniformBuffer: MTLBuffer?
    var pipeline: MTLComputePipelineState!
    var isDirty: Bool = true
    var kernelFunction: MTLFunction?
    var texture: MTLTexture! {
        if self.isDirty {
            self.applyFilter()
        }
        return self.internalTexture
    }
    var outputBuffer: MTLBuffer?
    var provider: GTextureProvider!
    var internalTexture: MTLTexture?

    init(functionName: String, context: GContext) {
        self.context = context
        self.kernelFunction = self.context.library.makeFunction(name: functionName)
        self.pipeline = try! self.context.device.makeComputePipelineState(function: self.kernelFunction!)
    }
    
    func configureArgumentTable(commandEncoder: MTLComputeCommandEncoder) {
    }
    
    func applyFilter() {
        let inputTexture = self.provider.texture!
        GZLogFunc(inputTexture)
        if self.internalTexture == nil ||
            self.internalTexture!.width != inputTexture.width ||
            self.internalTexture!.height != inputTexture.height {
            GZLogFunc("pixel format : \(inputTexture.pixelFormat.rawValue)")
            GZLogFunc("width : \(inputTexture.width)")
            GZLogFunc("height : \(inputTexture.height)")
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: inputTexture.pixelFormat, width: inputTexture.width, height: inputTexture.height, mipmapped: false)
            textureDescriptor.usage = MTLTextureUsage.init(rawValue: MTLTextureUsage.shaderWrite.rawValue | MTLTextureUsage.shaderRead.rawValue)
            self.internalTexture = self.context.device.makeTexture(descriptor: textureDescriptor)
            
            self.outputBuffer = self.context.device.makeBuffer(length: inputTexture.width * inputTexture.height * 4, options: [MTLResourceOptions.init(rawValue: 0)])
        }
        GZLogFunc("threadExecutionWidth: \(pipeline.threadExecutionWidth)")
        GZLogFunc("maxTotalThreadsPerThreadgroup: \(pipeline.maxTotalThreadsPerThreadgroup)")
        
        let threadgroupCounts = MTLSizeMake(pipeline.threadExecutionWidth, pipeline.maxTotalThreadsPerThreadgroup/pipeline.threadExecutionWidth, 1)
//        let threadgroupCounts = MTLSizeMake(8, 8, 1)
        let threadgroups = MTLSizeMake(inputTexture.width / threadgroupCounts.width, inputTexture.height / threadgroupCounts.height, 1)
    
        let commandBuffer = self.context.commandQueue.makeCommandBuffer()
        let commandEncoder = commandBuffer?.makeComputeCommandEncoder()
        commandEncoder?.setComputePipelineState(self.pipeline)
        commandEncoder?.setTexture(inputTexture, index: 0)
        commandEncoder?.setTexture(internalTexture, index: 1)
        GZLogFunc("\(inputTexture.width), \(inputTexture.height)")
        GZLogFunc("\(internalTexture?.width), \(internalTexture?.height)")
        self.configureArgumentTable(commandEncoder: commandEncoder!)
//        if #available(OSX 10.13, *) {
//            commandEncoder?.dispatchThreads(MTLSizeMake(1, 1, 1), threadsPerThreadgroup: threadgroupCounts)
//        } else {
            commandEncoder?.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: threadgroupCounts)
//        }
        commandEncoder?.endEncoding()

        let blitEncoder = commandBuffer?.makeBlitCommandEncoder()
        blitEncoder?.copy(from: internalTexture!, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOriginMake(0, 0, 0), sourceSize: MTLSizeMake(internalTexture!.width,internalTexture!.height,1), to: outputBuffer!, destinationOffset: 0, destinationBytesPerRow: internalTexture!.width * 4, destinationBytesPerImage: 0)
        blitEncoder?.endEncoding()
        
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
        GZLogFunc()
    }
    
}
