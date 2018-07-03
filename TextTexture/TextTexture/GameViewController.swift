//
//  GameViewController.swift
//  TextTexture
//
//  Created by LEE CHUL HYUN on 7/4/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import UIKit
import MetalKit

// Our iOS specific view controller
class GameViewController: UIViewController {

    var renderer: Renderer!
    @IBOutlet weak var mtkView: MTKView!
    @IBOutlet weak var imageView: UIImageView!

    var atlasGenerator: FontAtlasGenerator?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return
        }
        
        let font = UIFont.init(name: "AppleSDGothicNeo-Regular", size: 128)
        
        atlasGenerator = FontAtlasGenerator.init()
        atlasGenerator?.createTextureData(font: font!, string: "AB")
        self.imageView.image = atlasGenerator?.fontImage

        mtkView.device = defaultDevice
        mtkView.backgroundColor = UIColor.black

        guard let newRenderer = Renderer(metalKitView: mtkView, atlasGenerator: atlasGenerator!) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }
}
