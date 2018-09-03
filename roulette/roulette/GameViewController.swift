//
//  GameViewController.swift
//  roulette
//
//  Created by LEE CHUL HYUN on 8/6/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import UIKit
import MetalKit

// Our iOS specific view controller
class GameViewController: UIViewController {

    var renderer: Renderer!
    var offScreenRenderer: OffScreenRenderer!
    var mtkView: MTKView!

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let mtkView = view as? MTKView else {
            print("View of Gameview controller is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return
        }
        
        mtkView.device = defaultDevice
        mtkView.backgroundColor = UIColor.black

        guard let r = OffScreenRenderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }
        offScreenRenderer = r
        offScreenRenderer.draw(in: mtkView)
        GZLog(offScreenRenderer.texture)
        let t = offScreenRenderer.texture
        GZLog()
        

        guard let newRenderer = Renderer(metalKitView: mtkView, t: t!) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer
        renderer.illuminati = t!

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }
    
    @IBAction func rotationClicked(_ sender: Any) {
        GZLog()
        
        renderer.startRotation(duration: 7.5 + 10 * drand48(), endingRotationZ: Double.pi * 15 + Double.pi * 30 * drand48(),
                                timingFunction:  { (tx) -> Double in
                                    return pow(tx-1, 3) + 1
        })
    }
}
