//
//  ViewController.swift
//  environment
//
//  Created by LEE CHUL HYUN on 6/5/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import UIKit
import CoreMotion
import simd

class ViewController: UIViewController {
    
    var displayLink : CADisplayLink?
    var motionManager : CMMotionManager?
    
    var metalView : GMetalView {
        get {
            return self.view as! GMetalView
        }
    }
    
    deinit {
        SBLog.debug()
        displayLink?.invalidate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        self.navigationController?.navigationBar.isTranslucent = true
        self.navigationController?.view.backgroundColor = UIColor.clear
        self.navigationController?.navigationBar.backgroundColor = UIColor.clear
        self.navigationController?.navigationBar.tintColor = UIColor.red
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            displayLink?.add(to: RunLoop.main, forMode: .commonModes)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        AppDelegate.appProtocols.append(self)
        
        if self.motionManager == nil {
            self.motionManager = CMMotionManager()
        }
        if let motionManager = self.motionManager, motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1 / 60.9
            motionManager.startDeviceMotionUpdates(using: .xTrueNorthZVertical)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        SBLog.debug()
        super.viewWillDisappear(animated)
        
        let index = AppDelegate.appProtocols.index(where: { (appProtocol) -> Bool in
            if self.metalView === appProtocol {
                return true
            }
            return false
        })
        if index != nil {
            AppDelegate.appProtocols.remove(at: index!)
        }
        displayLink?.invalidate()
        displayLink = nil
        
        self.motionManager?.stopDeviceMotionUpdates()
        
        self.navigationController?.navigationBar.setBackgroundImage(nil, for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = nil
        self.navigationController?.navigationBar.tintColor = nil
        self.navigationController?.navigationBar.isTranslucent = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        SBLog.debug()
        super.viewDidDisappear(animated)
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [UIInterfaceOrientationMask.portrait]
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    @objc func displayLinkDidFire() {
        self.metalView.redraw()
    }
    
    func updateDeviceOrientation() {
        if let mm = self.motionManager, mm.isDeviceMotionAvailable, let motion = mm.deviceMotion {
            
            let m = motion.attitude.rotationMatrix
            
            // permute rotation matrix from Core Motion to get scene orientation
            let X = vector_float4( Float(m.m12), Float(m.m22), Float(m.m32), 0 )
            let Y = vector_float4( Float(m.m13), Float(m.m23), Float(m.m33), 0 )
            let Z = vector_float4( Float(m.m11), Float(m.m21), Float(m.m31), 0 )
            let W = vector_float4(     0,     0,     0, 1 )
            
            let orientation = matrix_float4x4( X, Y, Z, W )
            self.metalView.sceneOrientation = orientation
    }
    }
    
}

extension ViewController : AppProtocol {
    
    func applicationWillResignActive() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    func applicationDidBecomeActive() {
        
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidFire))
            displayLink?.add(to: RunLoop.main, forMode: .commonModes)
        }
    }
}

extension UINavigationController {
    
    open override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
        
        if let vc = self.visibleViewController {
            return vc.supportedInterfaceOrientations
        }
        
        // ViewController가 없는 경우 세로화면만
        let orientation: UIInterfaceOrientationMask = [UIInterfaceOrientationMask.portrait]
        return orientation
    }
    
    open override var shouldAutorotate : Bool {
        if let vc = self.visibleViewController {
            return vc.shouldAutorotate
        }
        
        // ViewController가 없는 경우 회전을 하지 않도록함
        return false
    }
}

