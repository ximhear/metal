//
//  NSImage-extension.swift
//  sdfgenerator
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
    
    /// init?(texture: MTLTexture?)으로 texture의 이미지를 얻어올 수 없다면 사용하자.
    ///
    /// - Parameters:
    ///   - buffer: MTLBuffer
    ///   - texture: MTLTexture
    convenience init?(buffer: MTLBuffer?, texture: MTLTexture?) {
        
        guard let buffer = buffer, let texture =  texture else {
            return nil
        }
        let imageSize = CGSize.init(width: texture.width, height: texture.height)
        let imageByteCount = Int(imageSize.width * imageSize.height * 4)
        let imageBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: imageByteCount)
        let bytesPerRow = Int(imageSize.width) * 4
        let contents = buffer.contents().bindMemory(to: UInt8.self, capacity: imageByteCount)
        imageBytes.assign(from: contents, count: imageByteCount)
        
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
