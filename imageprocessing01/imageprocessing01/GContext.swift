//
//  GContext.swift
//  imageprocessing01
//
//  Created by LEE CHUL HYUN on 5/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Cocoa
import Metal

class GContext: NSObject {
    var device: MTLDevice!
    var library: MTLLibrary!
    var commandQueue: MTLCommandQueue!
    
    override init() {
        super.init()
        
        device = MTLCreateSystemDefaultDevice()
        library = device.makeDefaultLibrary()
        commandQueue = device.makeCommandQueue()
    }
}
