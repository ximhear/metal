//
//  ViewController.swift
//  sdfgenerator
//
//  Created by LEE CHUL HYUN on 5/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    var context: GContext?
    var imageProvider: GTextureProvider?
    var desaturateFilter: GSaturationAdjustmentFilter?
    var blurFilter: GGaussianBlur2DFilter?
    @IBOutlet weak var imageView: NSImageView!
    
    var renderingQueue: DispatchQueue?
    var jobIndex: UInt = 0

    var atlas: MBEFontAtlas?
    override func viewDidLoad() {
        super.viewDidLoad()

        self.renderingQueue = DispatchQueue.init(label: "Rendering")
        
        let MBEFontAtlasSize: NSInteger = 64/*2048*/ * NSInteger(SCALE_FACTOR);
        let font = NSFont.init(name: "AppleSDGothicNeo-Regular", size: 64)
        atlas = MBEFontAtlas.init(font: font, textureSize: MBEFontAtlasSize)
        
        self.imageView.image = atlas?.fontImage
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
}

