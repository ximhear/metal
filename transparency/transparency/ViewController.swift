//
//  ViewController.swift
//  transparency
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
        GZLog()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
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
    }
}

