//
//  ViewController.swift
//  imageprocessing01
//
//  Created by LEE CHUL HYUN on 5/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func blurChanged(_ sender: Any) {
        if let slider = sender as? NSSlider {
            GZLogFunc("\(slider.doubleValue)")
        }
    }
    
    @IBAction func saturationChanged(_ sender: Any) {
        if let slider = sender as? NSSlider {
            GZLogFunc("\(slider.doubleValue)")
        }
    }
}

