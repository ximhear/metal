//
//  ViewController.swift
//  metal02
//
//  Created by LEE CHUL HYUN on 4/21/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    var metalView: GMetalView {
        return self.view as! GMetalView
    }
    @IBAction func rotationClicked(_ sender: Any) {
        GZLog()

        metalView.startRotation(duration: 10.0, endingRotationZ: Double.pi * 20.5,
                                timingFunction:  { (tx) -> Double in
                                    return pow(tx-1, 3) + 1
        },
                                speedFunction: { (tx) -> Double in
                                    return 3 * pow(tx-1, 2)
        })
    }
    
}

