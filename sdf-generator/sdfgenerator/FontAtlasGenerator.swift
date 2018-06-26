//
//  FontAtlasGenerator.swift
//  sdfgenerator
//
//  Created by chlee on 08/06/2018.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Foundation
import AppKit
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

class FontAtlasGenerator: NSObject, NSSecureCoding {
    var parentFont: NSFont?
    var fontPointSize: CGFloat = 0
    var spread: CGFloat = 0
    var glyphDescriptors = [GlyphDescriptor]()
    @objc var textureData: Data?
    @objc var textureWidth: Int = 0
    @objc var textureHeight: Int = 0
    var fontImage: NSImage?
    
    @objc func glyphDescriptor(at index: Int) -> GlyphDescriptor {
        return glyphDescriptors[index]
    }

    init(font: NSFont, textureSize: Int) {
        super.init()
        
        parentFont = font
        fontPointSize = font.pointSize
        spread = estimatedLineWidth(for: font) * 0.5
        self.textureWidth = textureSize
        self.textureHeight = textureSize
//        self.createTextureData()
    }

    init(font: NSFont) {
        super.init()
        
        parentFont = font
        fontPointSize = font.pointSize
        self.textureWidth = 0
        self.textureHeight = 0
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init()
        
        let fontSize = CGFloat(aDecoder.decodeFloat(forKey: MBEFontSizeKey))
        let spread = CGFloat(aDecoder.decodeFloat(forKey: MBEFontSpreadKey))
        
        guard let fontName = aDecoder.decodeObject(forKey: MBEFontNameKey) as? String, fontName.count > 0, fontSize > 0 else {
            GZLog("Encountered invalid persisted font (invalid font name or size). Aborting...")
            return nil
        }
    
        self.parentFont = NSFont.init(name: fontName, size: fontSize)
        self.fontPointSize = fontSize
        self.spread = spread
        self.glyphDescriptors = aDecoder.decodeObject(forKey: MBEGlyphDescriptorsKey) as? [GlyphDescriptor] ?? []
    
        if glyphDescriptors.count == 0 {
            GZLog("Encountered invalid persisted font (no glyph metrics). Aborting...")
            return nil
        }
    
        let width = aDecoder.decodeInteger(forKey: MBETextureWidthKey)
        let height = aDecoder.decodeInteger(forKey: MBETextureHeightKey)
        
        if width != height {
            GZLog("Encountered invalid persisted font (non-square textures aren't supported). Aborting...")
            return nil
        }
    
        self.textureWidth = width
        self.textureHeight = height
        self.textureData = aDecoder.decodeObject(forKey: MBETextureDataKey) as? Data
        if self.textureData == nil {
            GZLog("Encountered invalid persisted font (texture data is empty). Aborting...")
        }
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.parentFont?.fontName, forKey: MBEFontNameKey)
        aCoder.encode(Float(self.fontPointSize), forKey: MBEFontSizeKey)
        aCoder.encode(Float(self.spread), forKey: MBEFontSpreadKey)
        aCoder.encode(self.textureData, forKey: MBETextureDataKey)
        aCoder.encode(self.textureWidth, forKey: MBETextureWidthKey)
        aCoder.encode(self.textureHeight, forKey: MBETextureHeightKey)
        aCoder.encode(self.glyphDescriptors, forKey: MBEGlyphDescriptorsKey)
    }
    
    static var supportsSecureCoding: Bool {
        return true
    }
    
    func estimatedGlyphSize(for font: NSFont) -> CGSize {
        let exemplarString = "{ǺOJMQYZa@jmqyw" as NSString
        if #available(iOS 12.0, *) {
            let exemplarStringSize = exemplarString.size(withAttributes: [NSAttributedString.Key.font: font])
            let averageGlyphWidth: Float = ceilf(Float(exemplarStringSize.width / CGFloat(exemplarString.length)))
            let maxGlyphHeight: Float = ceilf(Float(exemplarStringSize.height))
            return CGSize.init(width: CGFloat(averageGlyphWidth), height: CGFloat(maxGlyphHeight))
        }
        else {
            let exemplarStringSize = exemplarString.size(withAttributes: [NSAttributedStringKey.font: font])
            let averageGlyphWidth: Float = ceilf(Float(exemplarStringSize.width / CGFloat(exemplarString.length)))
            let maxGlyphHeight: Float = ceilf(Float(exemplarStringSize.height))
            return CGSize.init(width: CGFloat(averageGlyphWidth), height: CGFloat(maxGlyphHeight))
        }
    }
    
    func estimatedLineWidth(for font: NSFont) -> CGFloat {
    //    return 50;
        let exemplarString = "!" as NSString
        if #available(iOS 12.0, *) {
            let exemplarStringSize = exemplarString.size(withAttributes: [NSAttributedString.Key.font: font])
            return CGFloat(ceilf(Float(exemplarStringSize.width)))
        }
        else {
            let exemplarStringSize = exemplarString.size(withAttributes: [NSAttributedStringKey.font: font])
            return CGFloat(ceilf(Float(exemplarStringSize.width)))
        }
    }
    
    func font(_ font: NSFont, atSize size: CGFloat, isLikelyToFitInAtlasRect rect: CGRect) -> Bool {
        let textureArea = rect.size.width * rect.size.height
        let trialFont = NSFont.init(name: font.fontName, size: size)
        let trialCTFont = CTFontCreateWithName(font.fontName as CFString, size, nil)
        let fontGlyphCount: CFIndex = CTFontGetGlyphCount(trialCTFont)
        let glyphMargin = self.estimatedLineWidth(for: trialFont!)
        let averageGlyphSize = self.estimatedGlyphSize(for: trialFont!)
        let estimatedGlyphTotalArea = (averageGlyphSize.width + glyphMargin) * (averageGlyphSize.height + glyphMargin) * CGFloat(fontGlyphCount)
        let fits = (estimatedGlyphTotalArea < textureArea)
        return fits
    }
    
    func pointSizeThatFits(for font:NSFont, inAtlasRect rect: CGRect) -> CGFloat {
        var fittedSize = font.pointSize
    
        while (self.font(font, atSize: fittedSize, isLikelyToFitInAtlasRect: rect)) {
            fittedSize += 1
        }
        while (self.font(font, atSize: fittedSize, isLikelyToFitInAtlasRect: rect) == false) {
            fittedSize -= 1
        }
        return fittedSize
    }
    

    func createAtlas(for font:NSFont, width: Int, height: Int) -> UnsafePointer<UInt8> {
        let imageData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let context = CGContext.init(data: imageData,
                                     width: width,
                                     height: height,
                                     bitsPerComponent: 8,
                                     bytesPerRow: width,
                                     space: colorSpace,
                                     bitmapInfo: 0)
        
        
        // Turn off antialiasing so we only get fully-on or fully-off pixels.
        // This implicitly disables subpixel antialiasing and hinting.
        context?.setAllowsAntialiasing(false)
        
        // Flip context coordinate space so y increases downward
        context?.translateBy(x: 0, y: CGFloat(height))
        context?.scaleBy(x: 1, y: -1)
        
        // Fill the context with an opaque black color
        context?.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        context?.fill(CGRect.init(x: 0, y: 0, width: width, height: height))
        
        fontPointSize = 64;//[self pointSizeThatFitsForFont:font inAtlasRect:CGRectMake(0, 0, width, height)];
        let ctFont = CTFontCreateWithName(font.fontName as CFString, fontPointSize, nil)
        parentFont = NSFont.init(name: font.fontName, size: fontPointSize)
//        let data = CTFontCopyTable(ctFont, CTFontTableTag(kCTFontTableCmap), CTFontTableOptions.init(rawValue: 0))
//        let set = CTFontCopyCharacterSet(ctFont) as NSCharacterSet
        
        let fontGlyphCount: CFIndex = CTFontGetGlyphCount(ctFont)
        
        let glyphMargin = self.estimatedLineWidth(for: parentFont!)
        
        // Set fill color so that glyphs are solid white
        context?.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        self.glyphDescriptors.removeAll()
        
        let fontAscent = CTFontGetAscent(ctFont)
        let fontDescent = CTFontGetDescent(ctFont)
        
        var origin = CGPoint.init(x: 0, y: fontAscent)
        var maxYCoordForLine: CGFloat = -1
        for glyph in 0..<fontGlyphCount {
            
            // A : 34
            //
            if (glyph != 2633) {
                continue
            }
            
            var boundingRect: CGRect = .zero
            var g = CGGlyph(glyph)
            CTFontGetBoundingRectsForGlyphs(ctFont, CTFontOrientation.horizontal, &g, &boundingRect, 1);
            
            if origin.x + boundingRect.maxX + glyphMargin > CGFloat(width) {
                origin.x = 0
                origin.y = maxYCoordForLine + glyphMargin + fontDescent
                maxYCoordForLine = -1
            }
            
            if origin.y + boundingRect.maxY > maxYCoordForLine {
                maxYCoordForLine = origin.y + boundingRect.maxY
            }
            
            let glyphOriginX = origin.x - boundingRect.origin.x + (glyphMargin * 0.5)
            let glyphOriginY = origin.y + (glyphMargin * 0.5)
            
            var glyphTransform = CGAffineTransform.init(a: 1, b: 0, c: 0, d: -1, tx: glyphOriginX, ty: glyphOriginY)
            
            let path = CTFontCreatePathForGlyph(ctFont, g, &glyphTransform)
            context?.addPath(path!)
            context?.fillPath()
            
            var glyphPathBoundingRect = path?.boundingBoxOfPath
            
            // The null rect (i.e., the bounding rect of an empty path) is problematic
            // because it has its origin at (+inf, +inf); we fix that up here
            if (glyphPathBoundingRect!.equalTo(CGRect.null)) {
                glyphPathBoundingRect = .zero;
            }
            
            let texCoordLeft = glyphPathBoundingRect!.origin.x / CGFloat(width)
            let texCoordRight = (glyphPathBoundingRect!.origin.x + glyphPathBoundingRect!.size.width) / CGFloat(width)
            let texCoordTop = (glyphPathBoundingRect!.origin.y) / CGFloat(height)
            let texCoordBottom = (glyphPathBoundingRect!.origin.y + glyphPathBoundingRect!.size.height) / CGFloat(height)
            
            let descriptor = GlyphDescriptor.init()
            descriptor.glyphIndex = g
            descriptor.topLeftTexCoord = CGPoint.init(x: texCoordLeft, y: texCoordTop)
            descriptor.bottomRightTexCoord = CGPoint.init(x: texCoordRight, y: texCoordBottom)
            
            self.glyphDescriptors.append(descriptor)
            
            origin.x +=  boundingRect.width + glyphMargin
        }
        
        let contextImage = context?.makeImage()
        // Break here to view the generated font atlas bitmap
        self.fontImage = NSImage.init(cgImage: contextImage!, size: NSSize.init(width: width, height: height))
        let image = self.fontImage
        GZLog()
        
        image?.writeToFile(file: "file:///Users/chlee/temp/font-atlas/aaa.jpg", atomically: true, usingType: NSBitmapImageRep.FileType.jpeg) // as jpg
        

//        for y in 0..<height {
//            var line = "[\(y)] ";
//            for x in 0..<width {
//                line = line + "\(imageData[y*width + x]),"
//            }
//            GZLog(line)
//        }
//        GZLog()

        //    for (int y = 0 ; y < height; y++) {
        //        NSString* line = @"";
        //        for (int x = 0 ; x < width; x++) {
        //            if (x == 0) {
        //                line = [[NSString alloc] initWithFormat:@"%x,", imageData[y*width + x]];
        //            }
        //            else {
        //                line = [[NSString alloc] initWithFormat:@"%@%x,", line, imageData[y*width + x]];
        //            }
        //        }
        //        NSLog(@"%@", line);
        //    }
        
        return UnsafePointer<UInt8>.init(imageData)
    }

    func createSignedDistanceFieldForGrayscaleImage(_ imageData: UnsafePointer<UInt8>?, width: Int, height: Int) -> UnsafePointer<Float>? {
        guard let imageData = imageData, width > 0, height > 0 else {
            return nil
        }
        
        struct intpoint_t {
            var x: Int
            var y: Int
        }
        
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
            GZLog(line)
        }
        GZLog()

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

    func createTextureData() {
        
        assert(MBEFontAtlasSize >= self.textureWidth,
               "Requested font atlas texture size \(MBEFontAtlasSize) must be smaller than intermediate texture size \(self.textureWidth)")
        
        assert(MBEFontAtlasSize % self.textureWidth == 0,
               "Requested font atlas texture size \(MBEFontAtlasSize) does not evenly divide intermediate texture size \(self.textureWidth)")
        
        // Generate an atlas image for the font, resizing if necessary to fit in the specified size.
        let atlasData = self.createAtlas(for:self.parentFont!,
                                         width:MBEFontAtlasSize,
                                         height:MBEFontAtlasSize)
        
        let scaleFactor = Int(MBEFontAtlasSize / self.textureWidth)
        
        // Create the signed-distance field representation of the font atlas from the rasterized glyph image.
        let distanceField = self.createSignedDistanceFieldForGrayscaleImage(atlasData, width: MBEFontAtlasSize, height: MBEFontAtlasSize)
        
        atlasData.deallocate()
        
        // Downsample the signed-distance field to the expected texture resolution
        let scaledField = self.createResampledData(distanceField!, width: MBEFontAtlasSize, height: MBEFontAtlasSize, scaleFactor: scaleFactor)
        
        distanceField?.deallocate()
        
        let spread: Float = Float(self.estimatedLineWidth(for: self.parentFont!) * 0.5)
        // Quantize the downsampled distance field into an 8-bit grayscale array suitable for use as a texture
        let texture = self.createQuantizedDistanceField(scaledField,
                                                        width:self.textureWidth,
                                                        height:self.textureHeight,
                                                        normalizationFactor:spread)
        
        scaledField.deallocate()
        
        
        let textureByteCount = self.textureWidth * self.textureHeight
        textureData = Data.init(bytes: texture, count: textureByteCount)
        texture.deallocate()
    }

    
    func createFontImage(for font: NSFont) -> Void {

        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        
        let fontGlyphCount: CFIndex = CTFontGetGlyphCount(ctFont)
        
        let a = Char2Index()
        var pair = [Int: Int]()
        if let dic = a.dic as? [Int: Int] {
            for key in dic.keys {
                pair[dic[key]!] = key
            }
        }
        
        GZLog(a.dic.count)
        GZLog(pair.count)
        GZLog()
        
        for glyph in 0..<fontGlyphCount {
            
            GZLog(glyph)
//            if (glyph > 300) {
//                break
//            }
            
            var boundingRect: CGRect = .zero
            var g = CGGlyph(glyph)
            CTFontGetBoundingRectsForGlyphs(ctFont, CTFontOrientation.horizontal, &g, &boundingRect, 1);
            
            let width = Int(ceilf(Float(boundingRect.width)))
            let height = Int(ceilf(Float(boundingRect.height)))
//            GZLog(width)
//            GZLog(height)
            if width == 0 || height == 0 {
                continue
            }
            let imageData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
            let context = CGContext.init(data: imageData,
                                         width: width,
                                         height: height,
                                         bitsPerComponent: 8,
                                         bytesPerRow: width,
                                         space: colorSpace,
                                         bitmapInfo: 0)
            
            
            // Turn off antialiasing so we only get fully-on or fully-off pixels.
            // This implicitly disables subpixel antialiasing and hinting.
            context?.setAllowsAntialiasing(false)
            
            // Flip context coordinate space so y increases downward
//            context?.translateBy(x: 0, y: CGFloat(height))
//            context?.scaleBy(x: 1, y: -1)
            
            // Fill the context with an opaque black color
            context?.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
            context?.fill(CGRect.init(x: 0, y: 0, width: width, height: height))
            
            // Set fill color so that glyphs are solid white
            context?.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            
            //            var glyphTransform = CGAffineTransform.init(a: 1, b: 0, c: 0, d: -1, tx: glyphOriginX, ty: glyphOriginY)
            var glyphTransform = CGAffineTransform.init(a: 1, b: 0, c: 0, d: 1, tx: -boundingRect.origin.x, ty: -boundingRect.origin.y)
            
            let path = CTFontCreatePathForGlyph(ctFont, g, &glyphTransform)
            context?.addPath(path!)
            context?.fillPath()
            
            let contextImage = context?.makeImage()
            // Break here to view the generated font atlas bitmap
            let image = NSImage.init(cgImage: contextImage!, size: NSSize.init(width: width, height: height))
            
            if let value = pair[glyph], let char = Unicode.Scalar.init(value) {
                let folderName = String.init(char)
                GZLog(folderName)
                do {
                    try FileManager.default.createDirectory(at: URL.init(fileURLWithPath: "/Users/gzonelee/temp/font-atlas/\(value)"), withIntermediateDirectories: true, attributes: nil)
                }
                catch {
                    GZLog(error)
                }
                image.writeToFile(file: "file:///Users/gzonelee/temp/font-atlas/\(value)/char.jpg", atomically: true, usingType: NSBitmapImageRep.FileType.jpeg) // as jpg
            }
            imageData.deallocate()
        }
    }

    func createFontImage(for font: NSFont, string: String, completion: (_ imageData: UnsafePointer<UInt8>, _ width: Int, _ height: Int) -> Void) -> Void {
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let lineSpacing: Int = 3
        
        let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)

        let characters = string.unicodeScalars.map { (scalar) in
            return UniChar.init(scalar.value)
        }
        var glyphs = Array<CGGlyph>.init(repeating: CGGlyph(0), count: string.count)
        CTFontGetGlyphsForCharacters(ctFont, characters, &glyphs, string.count)

        var maxWidth: Int = 0
        var totalHeight: Int = 0
        for glyph in glyphs {
            
            GZLog(glyph)
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
        totalHeight += (string.count - 1) * lineSpacing
        maxWidth = maxWidth * 11 / 10

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
        context?.setAllowsAntialiasing(false)
        
        // Flip context coordinate space so y increases downward
        //            context?.translateBy(x: 0, y: CGFloat(height))
        //            context?.scaleBy(x: 1, y: -1)
        
        // Fill the context with an opaque black color
        context?.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        context?.fill(CGRect.init(x: 0, y: 0, width: maxWidth, height: totalHeight))
        
        // Set fill color so that glyphs are solid white
        context?.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        
        var y: CGFloat = 0
        for glyph in glyphs {
            
            GZLog(glyph)
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
        let image = NSImage.init(cgImage: contextImage!, size: NSSize.init(width: maxWidth, height: totalHeight))
        
        do {
            try FileManager.default.createDirectory(at: URL.init(fileURLWithPath: "/Users/gzonelee/temp/font-atlas"), withIntermediateDirectories: true, attributes: nil)
        }
        catch {
            GZLog(error)
        }
        self.fontImage = image
        image.writeToFile(file: "file:///Users/gzonelee/temp/font-atlas/text.jpg", atomically: true, usingType: NSBitmapImageRep.FileType.jpeg) // as jpg

        completion(UnsafePointer<UInt8>.init(imageData), maxWidth, totalHeight)
    }
    
    func createTextureData(font: NSFont, string: String) {
        
        // Generate an atlas image for the font, resizing if necessary to fit in the specified size.
        createFontImage(for: font, string: string) { (atlasData, width, height) in
            
            
            self.textureWidth = width
            self.textureHeight = height
            // Create the signed-distance field representation of the font atlas from the rasterized glyph image.
            let distanceField = self.createSignedDistanceFieldForGrayscaleImage(atlasData, width: width, height: height)
            
            atlasData.deallocate()
            
            // Downsample the signed-distance field to the expected texture resolution
            let scaledField = self.createResampledData(distanceField!, width: width, height: height, scaleFactor: 1)
            
            distanceField?.deallocate()
            
            let spread: Float = Float(self.estimatedLineWidth(for: self.parentFont!) * 0.5)
            // Quantize the downsampled distance field into an 8-bit grayscale array suitable for use as a texture
            let texture = self.createQuantizedDistanceField(scaledField,
                                                            width: width,
                                                            height: height,
                                                            normalizationFactor: spread)
            
            scaledField.deallocate()
            
            
            let textureByteCount = width * height
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



extension NSImage {
    
    @discardableResult
    func writeToFile(file: String, atomically: Bool, usingType type: NSBitmapImageRep.FileType) -> Bool {
        let properties = [NSBitmapImageRep.PropertyKey.compressionFactor: 1.0]
        guard
            let imageData = tiffRepresentation,
            let imageRep = NSBitmapImageRep(data: imageData),
            let fileData = imageRep.representation(using: type, properties: properties) else {
                return false
        }
        do {
            if let url = URL.init(string: file) {
                try fileData.write(to: url)
            }
        }
        catch {
            GZLog(error)
            return false
        }
        return true
    }
}
