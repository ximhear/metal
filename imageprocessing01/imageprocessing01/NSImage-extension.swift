//
//  NSImage-extension.swift
//  imageprocessing01
//
//  Created by LEE CHUL HYUN on 5/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import AppKit
import Metal

extension NSImage {
    
    convenience init?(texture: MTLTexture?) {
        
        guard let texture = texture else {
            return nil
        }
        let imageSize = CGSize.init(width: texture.width, height: texture.height)
        let imageByteCount = Int(imageSize.width * imageSize.height * 4)
        let imageBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: imageByteCount)
//        let imageBytes = UnsafeMutableRawPointer.allocate(byteCount: imageByteCount, alignment: 1)
        let bytesPerRow = Int(imageSize.width) * 4
        let region = MTLRegionMake2D(0, 0, Int(imageSize.width), Int(imageSize.height))
        texture.getBytes(imageBytes, bytesPerRow: bytesPerRow, from: region, mipmapLevel: 0)
        let provider = CGDataProvider.init(dataInfo: nil, data: imageBytes, size: Int(imageByteCount)) { (raw1, raw2, val) in
            raw2.deallocate()
        }
        let bitsPerComponent = 8
        let bitsPerPixel = 32
        let space = CGColorSpaceCreateDeviceRGB()
        let renderingIntent: CGColorRenderingIntent = .defaultIntent

        let imageRef = CGImage.init(width: Int(imageSize.width),
                                    height: Int(imageSize.height),
                                    bitsPerComponent: bitsPerComponent,
                                    bitsPerPixel: bitsPerPixel,
                                    bytesPerRow: Int(bytesPerRow),
                                    space: space,
                                    bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue),
                                    provider: provider!,
                                    decode: nil,
                                    shouldInterpolate: false,
                                    intent: renderingIntent)
        self.init(cgImage: imageRef!, size: NSSize.init(width: imageSize.width, height: imageSize.height))
    }
}
