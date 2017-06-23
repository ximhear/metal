//
//  ViewController.swift
//  environment
//
//  Created by LEE CHUL HYUN on 6/5/17.
//  Copyright © 2017 LEE CHUL HYUN. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    var metalView : GMetalView {
        get {
            return self.view as! GMetalView
        }
    }
    
    deinit {
        SBLog.debug()
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        AppDelegate.appProtocols.append(self.metalView)
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

