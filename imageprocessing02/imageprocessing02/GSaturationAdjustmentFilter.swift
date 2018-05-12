//
//  GSaturationAdjustmentFilter.swift
//  imageprocessing01
//
//  Created by chlee on 11/05/2018.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import Metal

struct AdjustSaturationUniforms {
    var saturationFactor: Float
}

class GSaturationAdjustmentFilter: GImageFilter {
    
    var _saturationFactor: Float = 0
    var saturationFactor: Float {
        get {
            return _saturationFactor
        }
        set {
            self.isDirty = true
            _saturationFactor = newValue
        }
    }
    var uniforms: UnsafeMutablePointer<AdjustSaturationUniforms>

    init?(saturationFactor: Float, context: GContext) {
        guard let buffer = context.device.makeBuffer(length: MemoryLayout<AdjustSaturationUniforms>.size, options: [MTLResourceOptions.init(rawValue: 0)]) else { return nil }
        uniforms = UnsafeMutableRawPointer(buffer.contents()).bindMemory(to:AdjustSaturationUniforms.self, capacity:1)
        super.init(functionName: "adjust_saturation", context: context)
        _saturationFactor = saturationFactor
        uniformBuffer = buffer
    }
    
    override func configureArgumentTable(commandEncoder: MTLComputeCommandEncoder) {
        
        uniforms[0].saturationFactor = self.saturationFactor
        commandEncoder.setBuffer(self.uniformBuffer, offset: 0, index: 0)
    }
}
