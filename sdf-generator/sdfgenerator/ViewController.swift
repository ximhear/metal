//
//  ViewController.swift
//  sdfgenerator
//
//  Created by LEE CHUL HYUN on 5/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Cocoa
import MetalKit

class ViewController: NSViewController {

    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var mtkview: MTKView!
    
    var atlas: MBEFontAtlas?
    var atlasGenerator: FontAtlasGenerator?
    var renderer: AAPLRenderer?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        mtkview.device = MTLCreateSystemDefaultDevice()

        let MBEFontAtlasSize: NSInteger = 64/*2048*/ * NSInteger(SCALE_FACTOR);
        let font = NSFont.init(name: "AppleSDGothicNeo-Regular", size: 128)
//        let font = NSFont.init(name: "HoeflerText-Regular", size: 128)
        
//        atlas = MBEFontAtlas.init(font: font, textureSize: MBEFontAtlasSize)
//        self.imageView.image = atlas?.fontImage
//        renderer = AAPLRenderer.init(metalKitView: mtkview, atlas: atlas)

        atlasGenerator = FontAtlasGenerator.init(font: font!, textureSize: MBEFontAtlasSize)
//        atlasGenerator?.createTextureData()
//        atlasGenerator = FontAtlasGenerator.init(font: font!)
//        atlasGenerator?.createFontImage(for: font!, string: "a월드컵")
        atlasGenerator?.createTextureData(font: font!, string: "A월드컵")
        self.imageView.image = atlasGenerator?.fontImage
//        renderer = AAPLRenderer.init(metalKitView: mtkview, atlasGenerator: atlasGenerator)
        renderer = AAPLRenderer.init(metalKitView: mtkview, string: "hello", atlasGenerator: atlasGenerator)

        renderer?.mtkView(mtkview, drawableSizeWillChange: mtkview.drawableSize)
        self.mtkview.delegate = renderer
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

