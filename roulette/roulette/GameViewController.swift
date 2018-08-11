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

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
    }
    
    @IBAction func rotationClicked(_ sender: Any) {
        GZLog()
        
        renderer.stopRotation()
//        renderer.startRotation(duration: 10.0, endingRotationZ: Double.pi * 20.5,
//                                timingFunction:  { (tx) -> Double in
//                                    return pow(tx-1, 3) + 1
//        },
//                                speedFunction: { (tx) -> Double in
//                                    return 3 * pow(tx-1, 2)
//        })
    }
}
