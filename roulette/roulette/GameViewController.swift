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
    var menu: Menu?

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

//        guard let r = OffScreenRenderer(metalKitView: mtkView) else {
//            print("Renderer cannot be initialized")
//            return
//        }
//        offScreenRenderer = r
//        offScreenRenderer.draw(in: mtkView)
//        GZLog(offScreenRenderer.texture)
//        let t = offScreenRenderer.texture
//        let c = CIImage.init(mtlTexture: t!, options: nil)
//        GZLog()

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
        
        let counterClockwise = true
        let v0: Double = 7
        let a: Double = 0.3
        var duration: Double = v0 / a
        let endingRotationZ = Double.pi * 10 * v0
        if duration > 15 {
            duration = 15
        }
        renderer.startRotation(duration: duration, endingRotationZ: endingRotationZ,
                               counterClockwise: counterClockwise,
                               angleFunction: { (tx) -> Double in
                                let a = (pow(tx - 1, 3) + 1) * endingRotationZ
//                                let a =  (-pow(tx - 1, 2) + 1) * endingRotationZ
                                return a
        }, speedFunction: { (tx) -> Double in
            return v0 * pow(1 - tx / duration, 2)
//            return (v0 - tx * a) * 1
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

        
        items = []
        self.menu = menu
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
        
        renderer.rotationEnded = {[weak self] (angle) in
            self?.rotationEnded(angle: angle)
        }
    }
    
    func rotationEnded(angle: Double) {
        if items.count == 0 {
            return
        }
        let sectorAngle = Double.pi * 2 / Double(items.count)
        var a = angle.truncatingRemainder(dividingBy: Double.pi * 2.0)
        a = Double.pi * 2.0 - (a + Double.pi * 2.0).truncatingRemainder(dividingBy: Double.pi * 2.0)
        a = (a + sectorAngle / 2).truncatingRemainder(dividingBy: Double.pi * 2.0)
        GZLog(angle)
        GZLog(a)
        
        let index: Int = Int(a / sectorAngle)
        GZLog(index)

        do {
            let realm = try Realm()
            
            try realm.write {
                let historyItem = MenuHistoryItem()
                historyItem.title = items[index].text
                self.menu?.history.append(historyItem)
            }
        } catch let error as NSError {
            // If the encryption key is wrong, `error` will say that it's an invalid database
            fatalError("Error opening realm: \(error)")
        }

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
        else if segue.identifier == "showHistory" {
            let vc = (segue.destination as! UINavigationController).topViewController as! HistoryTableViewController
            do {
                let realm = try Realm()
                // Use the Realm as normal
                vc.history = realm.objects(MenuHistoryItem.self).sorted(byKeyPath: "created", ascending: false)
                vc.navigationItem.leftBarButtonItem = UIBarButtonItem.init(title: "닫기", style: .plain, target: self, action: #selector(closeVC(_:)))
                vc.navigationItem.leftItemsSupplementBackButton = true
            } catch let error as NSError {
                // If the encryption key is wrong, `error` will say that it's an invalid database
                fatalError("Error opening realm: \(error)")
            }
        }
    }

    @objc func closeVC(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    var prevMovePoint: CGPoint?
    var prevMoveTime: TimeInterval?
    var lastMovePoint: CGPoint?
    var lastMoveTime: TimeInterval?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        GZLog(touches.first?.location(in: self.view))
        prevMovePoint = nil
        prevMoveTime = nil
        lastMovePoint = nil
        lastMoveTime = nil
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        GZLog(touches.first?.location(in: self.view))
        
        if prevMovePoint == nil {
            prevMovePoint = touches.first?.location(in: self.view)
            prevMoveTime = touches.first?.timestamp
        }
        else {
            prevMovePoint = lastMovePoint
            prevMoveTime = lastMoveTime
        }
        lastMovePoint = touches.first?.location(in: self.view)
        lastMoveTime = touches.first?.timestamp
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        GZLog(touches.first?.location(in: self.view))
        GZLog(touches.first?.timestamp)
        
        if let pt = prevMovePoint, let tm = prevMoveTime,
            let endPt = lastMovePoint, let endTime = lastMoveTime {
            let diffTime = endTime - tm
            guard diffTime > 0 else {
                return
            }
//            GZLog(pt)
//            GZLog(endPt)
//            GZLog(tm)
//            GZLog(endTime)
//            GZLog("\(endPt.x - pt.x), \(endPt.y - pt.y)")
            let x = Double(endPt.x - pt.x)
            let y = Double(endPt.y - pt.y)
            let distance = sqrt(x * x + y * y)
            GZLog("distance : \(distance)")
            GZLog("time : \(diffTime)")
            let speed = sqrt(x * x + y * y) / diffTime
            let minSpeed: Double = 100
            let maxSpeed: Double = 10000
            GZLog("speed : \(speed)")
            if (distance < 3 && speed < minSpeed) /* || renderer.rotating == true*/ {
                GZLog("ignored")
            }
            else {
                let maxDuration: Double = 20
                let minV0: Double = 0.1
                let maxV0: Double = 8
                let v0 = (maxV0 - minV0) / (maxSpeed - minSpeed) * speed // 초기속도
                let a: Double = 0.2 // 가속도
                var duration = v0 / a
                GZLog("duratin : \(duration)")
                let midX = self.view.bounds.midX
                let midY = self.view.bounds.midY
                
                let x0: CGFloat = 0
                let y0: CGFloat = 0
                let x1: CGFloat = pt.x - midX
                let y1: CGFloat = midY - pt.y
                let x2: CGFloat = endPt.x - midX
                let y2: CGFloat = midY - endPt.y
                
//                var endingRotationZ = Double.pi * 2 * v0 / minimumSpeed
                var endingRotationZ = Double.pi * 10 * v0
                if duration < 5 {
                    duration = 5
                }
                else if duration > maxDuration {
                    duration = maxDuration
                }
                endingRotationZ += drand48() * Double.pi * 4

                let value = x0 * y1 + x1 * y2 + x2 * y0 - x1 * y0 - x2 * y1 - x0 * y2
                var counterClockwise = true
                
                if value < 0 {
                    counterClockwise = false
                    endingRotationZ = -endingRotationZ
                }
                
                GZLog(v0)
                GZLog(endingRotationZ)
                
                renderer.startRotation(duration: duration, endingRotationZ: endingRotationZ,
                                       counterClockwise: counterClockwise,
                                       angleFunction: { (tx) -> Double in
//                                        let a =  (-pow(tx - 1, 2) + 1) * endingRotationZ
                                        let a = (pow(tx - 1, 3) + 1) * endingRotationZ
//                                        print("\(tx) : \(a)")
                                        return a
                }, speedFunction: { (tx) -> Double in
//                    return (v0 -  v0 * pow(tx, 2) / duration / duration) * 3
//                    return (v0 - tx * a) * 1
                    return v0 * pow(1 - tx / duration, 2)
                })
            }
        }
    }
}
