//
//  GameViewController.swift
//  roulette
//
//  Created by LEE CHUL HYUN on 8/6/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import UIKit
import MetalKit
import RealmSwift

// Our iOS specific view controller
class GameViewController: UIViewController {

    var renderer: Renderer!
    var offScreenRenderer: OffScreenRenderer!
    var mtkView: MTKView!
    var items: [RouletteItem]!

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
        let c = CIImage.init(mtlTexture: t!, options: nil)
        GZLog()

        self.mtkView = mtkView
        if let menu = latestRoulette() {
            applyRoulette(menu: menu)
        }
        else {
            items = [
                RouletteItem(text: "Pandas", color: simd_float4(1, 0, 0, 1), textColor: simd_float4(0, 1, 1, 1), bgColor: simd_float4(1, 0, 0, 1)),
                RouletteItem(text: "Python", color: simd_float4(1, 1, 0, 1), textColor: simd_float4(0, 0, 1, 1), bgColor: simd_float4(1, 1, 0, 1)),
                RouletteItem(text: "커피", color: simd_float4(0, 1, 0, 1), textColor: simd_float4(1, 0, 1, 1), bgColor: simd_float4(0, 1, 0, 1)),
                RouletteItem(text: "구름", color: simd_float4(0, 1, 1, 1), textColor: simd_float4(1, 0, 0, 1), bgColor: simd_float4(0, 1, 1, 1)),
                RouletteItem(text: "아이패드", color: simd_float4(0, 0, 1, 1), textColor: simd_float4(1, 1, 0, 1), bgColor: simd_float4(0, 0, 1, 1)),
                RouletteItem(text: "베이블래이드", color: simd_float4(1, 0, 1, 1), textColor: simd_float4(0, 1, 0, 1), bgColor: simd_float4(1, 0, 1, 1)),
                RouletteItem(text: "METAL", color: simd_float4(Float(0x21)/255, Float(0xff)/255, Float(0xc5)/255, 1), textColor: simd_float4(0, 0, 0, 1), bgColor: simd_float4(Float(0x21)/255, Float(0xff)/255, Float(0xc5)/255, 1)),
            ]
            applyRoulette(count: 6)
        }
    }
    
    @IBAction func rotationClicked(_ sender: Any) {
        GZLog()
        
        renderer.startRotation(duration: 7.5 + 10 * drand48(), endingRotationZ: Double.pi * 15 + Double.pi * 30 * drand48(),
                                timingFunction:  { (tx) -> Double in
                                    return pow(tx-1, 3) + 1
        })
    }
    
    func latestRoulette() -> Menu? {
        
        let t = UserDefaults.standard.double(forKey: "roulette")
        if t == 0 {
            return nil
        }
        do {
            let realm = try Realm()
            if let menu = realm.objects(Menu.self).filter("created == %@", Date(timeIntervalSince1970: t)).first {
                return menu
            }
        } catch let error as NSError {
            // If the encryption key is wrong, `error` will say that it's an invalid database
            fatalError("Error opening realm: \(error)")
        }
        return nil
    }

    func applyRoulette(menu: Menu) {
        
        let colors: [(color: simd_float4, textColor: simd_float4, bgCololr: simd_float4)] = [
            (simd_float4(1, 0, 0, 1), simd_float4(0, 1, 1, 1), simd_float4(1, 0, 0, 1)),
            (simd_float4(1, 1, 0, 1), simd_float4(0, 0, 1, 1), simd_float4(1, 1, 0, 1)),
            (simd_float4(0, 1, 0, 1), simd_float4(1, 0, 1, 1), simd_float4(0, 1, 0, 1)),
            (simd_float4(0, 1, 1, 1), simd_float4(1, 0, 0, 1), simd_float4(0, 1, 1, 1)),
            (simd_float4(0, 0, 1, 1), simd_float4(1, 1, 0, 1), simd_float4(0, 0, 1, 1)),
            (simd_float4(1, 0, 1, 1), simd_float4(0, 1, 0, 1), simd_float4(1, 0, 1, 1)),
            (simd_float4(Float(0x21)/255, Float(0xff)/255, Float(0xc5)/255, 1), simd_float4(0, 0, 0, 1), simd_float4(Float(0x21)/255, Float(0xff)/255, Float(0xc5)/255, 1))]

        
        var items: [RouletteItem] = []
        for (index, x) in menu.items.enumerated() {
            let a = colors[index % 7]
            items.append(RouletteItem(text: x.title, color: a.color, textColor: a.textColor, bgColor: a.bgCololr))
        }
        guard let newRenderer = Renderer(metalKitView: mtkView, items: items) else {
            print("Renderer cannot be initialized")
            return
        }
        
        renderer = newRenderer
        
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        
        mtkView.delegate = renderer
    }
    

    func applyRoulette(count: Int) {
        
        var items: [RouletteItem] = []
        for x in 0..<count {
            items.append(self.items[x])
        }
        guard let newRenderer = Renderer(metalKitView: mtkView, items: items) else {
            print("Renderer cannot be initialized")
            return
        }
        
        renderer = newRenderer
        
        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)
        
        mtkView.delegate = renderer
    }

    @IBAction func b2Clicked(_ sender: Any) {
        applyRoulette(count: 2)
    }

    @IBAction func b3Clicked(_ sender: Any) {
        applyRoulette(count: 3)
    }

    @IBAction func b4Clicked(_ sender: Any) {
        applyRoulette(count: 4)
    }

    @IBAction func b5Clicked(_ sender: Any) {
        applyRoulette(count: 5)
    }

    @IBAction func b6Clicked(_ sender: Any) {
        applyRoulette(count: 6)
    }

    @IBAction func b7Clicked(_ sender: Any) {
        applyRoulette(count: 7)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSelection" {
            let vc = (segue.destination as! UINavigationController).topViewController as! MenuSelectionViewController
            vc.selectionChanged = {[weak self] (menu) in
                UserDefaults.standard.set(menu.created.timeIntervalSince1970, forKey: "roulette")
                self?.applyRoulette(menu: menu)
                DispatchQueue.main.async {
                    vc.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

}
