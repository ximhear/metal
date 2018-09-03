//
//  FontAtlasGenerator.swift
//  sdfgenerator
//
//  Created by chlee on 08/06/2018.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import UIKit
import CoreText

fileprivate let SCALE_FACTOR = 1
fileprivate let MBEFontAtlasSize = 128/*4096*/ * SCALE_FACTOR;

fileprivate let MBEGlyphIndexKey = "glyphIndex"
fileprivate let MBELeftTexCoordKey = "leftTexCoord"
fileprivate let MBERightTexCoordKey = "rightTexCoord"
fileprivate let MBETopTexCoordKey = "topTexCoord"
fileprivate let MBEBottomTexCoordKey = "bottomTexCoord"
fileprivate let MBEFontNameKey = "fontName"
fileprivate let MBEFontSizeKey = "fontSize"
fileprivate let MBEFontSpreadKey = "spread"
fileprivate let MBETextureDataKey = "textureData"
fileprivate let MBETextureWidthKey = "textureWidth"
fileprivate let MBETextureHeightKey = "textureHeight"
fileprivate let MBEGlyphDescriptorsKey = "glyphDescriptors"

let MBE_GENERATE_DEBUG_ATLAS_IMAGE = 1

class GlyphDescriptor : NSObject, NSSecureCoding {
    var glyphIndex: CGGlyph = 0
    @objc var topLeftTexCoord = CGPoint.zero
    @objc var bottomRightTexCoord = CGPoint.zero
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
        glyphIndex = UInt16(aDecoder.decodeInt64(forKey: MBELeftTexCoordKey))
        topLeftTexCoord.x = CGFloat(aDecoder.decodeFloat(forKey: MBELeftTexCoordKey))
        topLeftTexCoord.y = CGFloat(aDecoder.decodeFloat(forKey: MBETopTexCoordKey))
        bottomRightTexCoord.x = CGFloat(aDecoder.decodeFloat(forKey: MBERightTexCoordKey))
        bottomRightTexCoord.y = CGFloat(aDecoder.decodeFloat(forKey: MBEBottomTexCoordKey))
    }
    
    override init() {
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(Int64(glyphIndex), forKey: MBEGlyphIndexKey)
        aCoder.encode(Float(self.topLeftTexCoord.x), forKey: MBELeftTexCoordKey)
        aCoder.encode(Float(self.topLeftTexCoord.y), forKey: MBETopTexCoordKey)
        aCoder.encode(Float(self.bottomRightTexCoord.x), forKey: MBERightTexCoordKey)
        aCoder.encode(Float(self.bottomRightTexCoord.y), forKey: MBEBottomTexCoordKey)
    }
    
    static var supportsSecureCoding: Bool {
        return true
    }
}

class FontAtlasGenerator: NSObject {
    var glyphDescriptors = [GlyphDescriptor]()
    @objc var textureData: Data?
    @objc var textureWidth: Int = 0
    @objc var textureHeight: Int = 0
    var fontImage: UIImage?
    
    @objc func glyphDescriptor(at index: Int) -> GlyphDescriptor {
        return glyphDescriptors[index]
    }

    func estimatedGlyphSize(for font: UIFont) -> CGSize {
        let exemplarString = "{ǺOJMQYZa@jmqyw" as NSString
        let exemplarStringSize = exemplarString.size(withAttributes: [NSAttributedString.Key.font: font])
        let averageGlyphWidth: Float = ceilf(Float(exemplarStringSize.width / CGFloat(exemplarString.length)))
        let maxGlyphHeight: Float = ceilf(Float(exemplarStringSize.height))
        return CGSize.init(width: CGFloat(averageGlyphWidth), height: CGFloat(maxGlyphHeight))
    }
    
    func estimatedLineWidth(for font: UIFont) -> CGFloat {
    //    return 50;
        let exemplarString = "!" as NSString
        let exemplarStringSize = exemplarString.size(withAttributes: [NSAttributedString.Key.font: font])
        return CGFloat(ceilf(Float(exemplarStringSize.width)))
    }
    
    func font(_ font: UIFont, atSize size: CGFloat, isLikelyToFitInAtlasRect rect: CGRect) -> Bool {
        let textureArea = rect.size.width * rect.size.height
        let trialFont = UIFont.init(name: font.fontName, size: size)
        let trialCTFont = CTFontCreateWithName(font.fontName as CFString, size, nil)
        let fontGlyphCount: CFIndex = CTFontGetGlyphCount(trialCTFont)
        let glyphMargin = self.estimatedLineWidth(for: trialFont!)
        let averageGlyphSize = self.estimatedGlyphSize(for: trialFont!)
        let estimatedGlyphTotalArea = (averageGlyphSize.width + glyphMargin) * (averageGlyphSize.height + glyphMargin) * CGFloat(fontGlyphCount)
        let fits = (estimatedGlyphTotalArea < textureArea)
        return fits
    }
    
    func pointSizeThatFits(for font:UIFont, inAtlasRect rect: CGRect) -> CGFloat {
        var fittedSize = font.pointSize
    
        while (self.font(font, atSize: fittedSize, isLikelyToFitInAtlasRect: rect)) {
            fittedSize += 1
        }
        while (self.font(font, atSize: fittedSize, isLikelyToFitInAtlasRect: rect) == false) {
            fittedSize -= 1
        }
        return fittedSize
    }
    

    func createSignedDistanceFieldForGrayscaleImage(_ imageData: UnsafePointer<UInt8>?, width: Int, height: Int) -> UnsafePointer<Float>? {
        guard let imageData = imageData, width > 0, height > 0 else {
            return nil
        }
        
        struct intpoint_t {
            var x: Int
            var y: Int
        }
        
//        let title = (0..<width).map { (a) in
//            return "\(a)"
//        }
//        print(title.joined(separator: ","))
//        for y in 0..<height {
//            var values = [String]()
//            for x in 0..<width {
//                values.append("\(imageData[y * width + x])")
//            }
//            print(values.joined(separator: ","))
//        }
//        GZLog()
        
        let distanceMap = UnsafeMutablePointer<Float>.allocate(capacity: width * height)
        let boundaryPointMap = UnsafeMutablePointer<intpoint_t>.allocate(capacity: width * height)
        
        let image: (_ x: Int, _ y: Int) -> Bool = { imageData[$1 * width + $0] > 0x7f }
        let distance: (_ x: Int, _ y: Int) -> Float = { distanceMap[$1 * width + $0] }
        let nearestpt: (_ x: Int, _ y: Int) -> intpoint_t = { boundaryPointMap[$1 * width + $0] }
        let setDistance: (_ x: Int, _ y: Int, _ distance: Float) -> Void = { distanceMap[$1 * width + $0] = $2 }
        let setNearestpt: (_ x: Int, _ y: Int, _ pt: intpoint_t) -> Void = { boundaryPointMap[$1 * width + $0] = $2 }

        let maxDist = hypotf(Float(width), Float(height))
        let distUnit: Float = 1
        let distDiag = sqrtf(2)
        
        // Initialization phase: set all distances to "infinity"; zero out nearest boundary point map
        for y in 0..<height {
            for x in 0..<width {
                setDistance(x, y, maxDist)
                setNearestpt(x, y, intpoint_t.init(x: 0, y: 0))
            }
        }
        
        // Immediate interior/exterior phase: mark all points along the boundary as such
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let inside = image(x, y)
                if (image(x - 1, y) != inside ||
                    image(x + 1, y) != inside ||
                    image(x, y - 1) != inside ||
                    image(x, y + 1) != inside)
                {
                    setDistance(x, y, 0)
                    setNearestpt(x, y, intpoint_t.init(x: x, y: y))
                }
            }
        }
        
//        let title = (0..<width).map { (a) in
//            return "\(a)"
//        }
//        print(title.joined(separator: ","))
//        for y in 0..<height {
//            var values = [String]()
//            for x in 0..<width {
//                if distanceMap[y * width + x] == 0 {
//                    values.append("X")
//                }
//                else {
//                    values.append(".")
//                }
//            }
//            print(values.joined(separator: ","))
//        }
//        GZLog()

//        for y in 0..<height {
//            var line = "[\(y)] ";
//            for x in 0..<width {
//                line = line + "\(distance(x, y)),"
//            }
//            GZLog(line)
//        }
//        GZLog()

        // Forward dead-reckoning pass
        for y in 1..<(height - 2) {
            for x in 1..<(width - 2) {
                if (distanceMap[(y - 1) * width + (x - 1)] + distDiag < distance(x, y)) {
                    setNearestpt(x, y, nearestpt(x - 1, y - 1))
                    setDistance(x, y, hypotf(Float(x - nearestpt(x, y).x), Float(y - nearestpt(x, y).y)))
                }
                if (distance(x, y - 1) + distUnit < distance(x, y)) {
                    setNearestpt(x, y, nearestpt(x, y - 1))
                    setDistance(x, y, hypotf(Float(x - nearestpt(x, y).x), Float(y - nearestpt(x, y).y)))
                }
                if (distance(x + 1, y - 1) + distDiag < distance(x, y)) {
                    setNearestpt(x, y, nearestpt(x + 1, y - 1))
                    setDistance(x, y, hypotf(Float(x - nearestpt(x, y).x), Float(y - nearestpt(x, y).y)))
                }
                if (distance(x - 1, y) + distUnit < distance(x, y)) {
                    setNearestpt(x, y, nearestpt(x - 1, y))
                    setDistance(x, y, hypotf(Float(x - nearestpt(x, y).x), Float(y - nearestpt(x, y).y)))
                }
            }
        }
        
//        for y in 0..<height {
//            var line = "[\(y)] ";
//            for x in 0..<width {
//                line = line + "\(distance(x, y)),"
//            }
//            GZLog(line)
//        }
//        GZLog()

        // Backward dead-reckoning pass
        for y in (1..<height - 1).reversed() {
            for x in (1..<width - 1).reversed() {
                if (distance(x + 1, y) + distUnit < distance(x, y)) {
                    setNearestpt(x, y, nearestpt(x + 1, y))
                    setDistance(x, y, hypotf(Float(x - nearestpt(x, y).x), Float(y - nearestpt(x, y).y)))
                }
                if (distance(x - 1, y + 1) + distDiag < distance(x, y)) {
                    setNearestpt(x, y, nearestpt(x - 1, y + 1))
                    setDistance(x, y, hypotf(Float(x - nearestpt(x, y).x), Float(y - nearestpt(x, y).y)))
                }
                if (distance(x, y + 1) + distUnit < distance(x, y)) {
                    setNearestpt(x, y, nearestpt(x, y + 1))
                    setDistance(x, y, hypotf(Float(x - nearestpt(x, y).x), Float(y - nearestpt(x, y).y)))
                }
                if (distance(x + 1, y + 1) + distDiag < distance(x, y)) {
                    setNearestpt(x, y, nearestpt(x + 1, y + 1))
                    setDistance(x, y, hypotf(Float(x - nearestpt(x, y).x), Float(y - nearestpt(x, y).y)))
                }
            }
        }

//        let title = (0..<width).map { (a) in
//            return "\(a)"
//        }
//        print(title.joined(separator: ","))
//        for y in 0..<height {
//            var values = [String]()
//            for x in 0..<width {
//                values.append(String(format: "%.2f", distanceMap[y * width + x]))
//            }
//            print(values.joined(separator: ","))
//        }
//        GZLog()

//        for y in 0..<height {
//            var line = "[\(y)] ";
//            for x in 0..<width {
//                line = line + "\(distance(x, y)),"
//            }
//            GZLog(line)
//        }
//        GZLog()

        // Interior distance negation pass; distances outside the figure are considered negative
        for y in 0..<height {
            for x in 0..<width {
                if (!image(x, y)) {
                    setDistance(x, y, -distance(x, y))
                }
            }
        }

//        let title = (0..<width).map { (a) in
//            return "\(a)"
//        }
//        print(title.joined(separator: ","))
//        for y in 0..<height {
//            var values = [String]()
//            for x in 0..<width {
//                values.append(String(format: "%.2f", distanceMap[y * width + x]))
//            }
//            print(values.joined(separator: ","))
//        }
//        GZLog()

//        for y in 0..<height {
//            var line = "[\(y)] ";
//            for x in 0..<width {
//                line = line + "\(distance(x, y)),"
//            }
//            GZLog(line)
//        }
//        GZLog()

        boundaryPointMap.deallocate()
        
        return UnsafePointer<Float>.init(distanceMap)
    }
    
    func createResampledData(_ inData: UnsafePointer<Float>, width: Int, height: Int, scaleFactor: Int) -> UnsafePointer<Float> {
        assert(width % scaleFactor == 0 && height % scaleFactor == 0,
                 "Scale factor does not evenly divide width and height of source distance field")
        
        let scaledWidth = width / scaleFactor
        let scaledHeight = height / scaleFactor
        let outData = UnsafeMutablePointer<Float>.allocate(capacity: scaledWidth * scaledHeight)
        
        for y in (0..<scaledHeight).map({ $0 * scaleFactor }) {
            for x in (0..<scaledWidth).map({ $0 * scaleFactor }) {
                var accum: Float = 0
                for ky in 0..<scaleFactor {
                    for kx in 0..<scaleFactor {
                        accum += inData[(y + ky) * width + (x + kx)];
                    }
                }
                accum = accum / Float(scaleFactor * scaleFactor)
                
                outData[(y / scaleFactor) * scaledWidth + (x / scaleFactor)] = accum
            }
        }

//        let title = (0..<scaledWidth).map { (a) in
//            return "\(a)"
//        }
//        print(title.joined(separator: ","))
//        for y in 0..<scaledHeight {
//            var values = [String]()
//            for x in 0..<scaledWidth {
//                values.append(String(format: "%.2f", outData[y * scaledWidth + x]))
//            }
//            print(values.joined(separator: ","))
//        }
//        GZLog()

        
//        for y in 0..<scaledHeight {
//            var line = "";
//            for x in 0..<scaledWidth {
//                line = line + "\(outData[y*scaledWidth + x]),"
//            }
//            GZLog(line)
//        }
//        GZLog()
        
        return UnsafePointer<Float>.init(outData)
    }
    
    func createQuantizedDistanceField(_ inData: UnsafePointer<Float>, width: Int, height: Int, normalizationFactor: Float) -> UnsafePointer<UInt8> {
        
        let outData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)

        for y in 0..<height {
            for x in 0..<width {
                let dist = inData[y * width + x]
                let clampDist = fmax(-normalizationFactor, fmin(dist, normalizationFactor))
                let scaledDist = clampDist / normalizationFactor
                let value: UInt8 = UInt8((scaledDist + 1) / 2 * Float(UInt8.max))
                outData[y * width + x] = value;
            }
        }

        for y in 0..<height {
            var line = "";
            for x in 0..<width {
                line = line + "\(outData[y*width + x]),"
            }
//            GZLog(line)
        }
//        GZLog()

        let title = (0..<width).map { (a) in
            return "\(a)"
        }
//        print(title.joined(separator: ","))
        for y in 0..<height {
            var values = [String]()
            for x in 0..<width {
                values.append("\(outData[y * width + x])")
            }
//            print(values.joined(separator: ","))
        }
//        GZLog()

//        for (long y = 0; y < height; ++y) {
//            NSString* line = @"";
//            for (long x = 0; x < width; ++x) {
//                if (x == 0) {
//                    line = [[NSString alloc] initWithFormat:@"%x,", outData[y*width + x]];
//                }
//                else {
//                    line = [[NSString alloc] initWithFormat:@"%@%x,", line, outData[y*width + x]];
//                }
//            }
//            NSLog(@"%@", line);
//        }
//        NSLog(@"");
        
        return UnsafePointer<UInt8>.init(outData)
    }

    func createFontImage(for font: UIFont, string: String, completion: (_ imageData: UnsafePointer<UInt8>, _ width: Int, _ height: Int) -> Void) -> Void {
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let lineSpacing: Int = 8
        
        let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)

        let characters = string.unicodeScalars.map { (scalar) in
            return UniChar.init(scalar.value)
        }
        var glyphs = Array<CGGlyph>.init(repeating: CGGlyph(0), count: string.count)
        CTFontGetGlyphsForCharacters(ctFont, characters, &glyphs, string.count)

        var maxWidth: Int = 0
        var totalHeight: Int = lineSpacing
        for glyph in glyphs {
            
//            GZLog(glyph)
            var rect: CGRect = .zero
            var g = glyph
            CTFontGetBoundingRectsForGlyphs(ctFont, CTFontOrientation.horizontal, &g, &rect, 1)
            let width = Int(ceilf(Float(rect.width)))
            let height = Int(ceilf(Float(rect.height)))
            if width == 0 || height == 0 {
                continue
            }
            if maxWidth < width {
                maxWidth = width
            }
            totalHeight += height
        }
        totalHeight += (string.count + 1) * lineSpacing
        maxWidth = maxWidth * 14 / 10
        if totalHeight % 2 == 1 {
            totalHeight += 1
        }
        if maxWidth % 2 == 1 {
            maxWidth += 1
        }

        let imageData = UnsafeMutablePointer<UInt8>.allocate(capacity: maxWidth * totalHeight)
        let context = CGContext.init(data: imageData,
                                     width: maxWidth,
                                     height: totalHeight,
                                     bitsPerComponent: 8,
                                     bytesPerRow: maxWidth,
                                     space: colorSpace,
                                     bitmapInfo: 0)

        // Turn off antialiasing so we only get fully-on or fully-off pixels.
        // This implicitly disables subpixel antialiasing and hinting.
        context?.setAllowsAntialiasing(true)
        
        // Flip context coordinate space so y increases downward
        //            context?.translateBy(x: 0, y: CGFloat(height))
        //            context?.scaleBy(x: 1, y: -1)
        
        // Fill the context with an opaque black color
        context?.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        context?.fill(CGRect.init(x: 0, y: 0, width: maxWidth, height: totalHeight))
        
        // Set fill color so that glyphs are solid white
        context?.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        var y: CGFloat = CGFloat(lineSpacing)
        for glyph in glyphs {
            
//            GZLog(glyph)
            var boundingRect: CGRect = .zero
            var g = glyph
            CTFontGetBoundingRectsForGlyphs(ctFont, CTFontOrientation.horizontal, &g, &boundingRect, 1);
            
            let width = Int(ceilf(Float(boundingRect.width)))
            let height = Int(ceilf(Float(boundingRect.height)))
            //            GZLog(width)
            //            GZLog(height)
            if width == 0 || height == 0 {
                continue
            }
            
            //            var glyphTransform = CGAffineTransform.init(a: 1, b: 0, c: 0, d: -1, tx: glyphOriginX, ty: glyphOriginY)
            var glyphTransform = CGAffineTransform.init(a: 1, b: 0, c: 0, d: 1, tx: (CGFloat(maxWidth) - boundingRect.width - boundingRect.origin.x)/2, ty: CGFloat(totalHeight) - boundingRect.maxY - y)
            
            let path = CTFontCreatePathForGlyph(ctFont, g, &glyphTransform)
            context?.addPath(path!)
            
            y += CGFloat(height) + CGFloat(lineSpacing)
        }
        context?.fillPath()
        
        let contextImage = context?.makeImage()
        // Break here to view the generated font atlas bitmap
        let image = UIImage.init(cgImage: contextImage!)
        
        self.fontImage = image

        completion(UnsafePointer<UInt8>.init(imageData), maxWidth, totalHeight)
    }
    
    func createTextureData(font: UIFont, string: String) {
        
        // Generate an atlas image for the font, resizing if necessary to fit in the specified size.
        createFontImage(for: font, string: string) { (atlasData, width, height) in
            
            
            self.textureWidth = width / 2
            self.textureHeight = height / 2
            // Create the signed-distance field representation of the font atlas from the rasterized glyph image.
            let distanceField = self.createSignedDistanceFieldForGrayscaleImage(atlasData, width: width, height: height)
            
            atlasData.deallocate()
            
            // Downsample the signed-distance field to the expected texture resolution
            let scaledField = self.createResampledData(distanceField!, width: width, height: height, scaleFactor: 2)
            
            distanceField?.deallocate()
            
            let spread: Float = Float(self.estimatedLineWidth(for: font) * 0.5)
            // Quantize the downsampled distance field into an 8-bit grayscale array suitable for use as a texture
            let texture = self.createQuantizedDistanceField(scaledField,
                                                            width: self.textureWidth,
                                                            height: self.textureHeight,
                                                            normalizationFactor: spread)
            
            scaledField.deallocate()
            
            
            let textureByteCount = self.textureWidth * self.textureHeight
            textureData = Data.init(bytes: texture, count: textureByteCount)
            texture.deallocate()
            self.glyphDescriptors.removeAll()
            let descriptor = GlyphDescriptor.init()
            descriptor.glyphIndex = 0
            descriptor.topLeftTexCoord = CGPoint.init(x: 0, y: 0)
            descriptor.bottomRightTexCoord = CGPoint.init(x: 1, y: 1)
            
            self.glyphDescriptors.append(descriptor)
        }
    }
}
