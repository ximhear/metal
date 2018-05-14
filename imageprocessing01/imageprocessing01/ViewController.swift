//
//  ViewController.swift
//  imageprocessing01
//
//  Created by LEE CHUL HYUN on 5/11/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var imageView:  NSImageView!
    @IBOutlet weak var blurRadiusSlider:  NSSlider!
    @IBOutlet weak var saturationSlider:  NSSlider!

    var context: GContext?
    var imageProvider: GTextureProvider?
    var desaturateFilter: GSaturationAdjustmentFilter?
    var blurFilter: GGaussianBlur2DFilter?
    
    var renderingQueue: DispatchQueue?
    var jobIndex: UInt = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        self.renderingQueue = DispatchQueue.init(label: "Rendering")
        
        buildFilterGraph()
        updateImage()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

    @IBAction func blurChanged(_ sender: Any) {
        if let slider = sender as? NSSlider {
            GZLogFunc("\(slider.doubleValue)")
            updateImage()
        }
    }
    
    @IBAction func saturationChanged(_ sender: Any) {
        if let slider = sender as? NSSlider {
            GZLogFunc("\(slider.doubleValue)")
            updateImage()
        }
    }
    
    func buildFilterGraph() {
        self.context = GContext()
        
        self.imageProvider = MainBundleTextureProvider.init(imageName: "mandrill", context: self.context!)
        self.desaturateFilter = GSaturationAdjustmentFilter.init(saturationFactor: self.saturationSlider.floatValue, context: self.context!)
        self.desaturateFilter?.provider = self.imageProvider!
        
        GZLogFunc(self.blurRadiusSlider.floatValue)
        GZLogFunc(self.saturationSlider.floatValue)
        self.blurFilter = GGaussianBlur2DFilter.init(radius: self.blurRadiusSlider.floatValue, context: self.context!)
        self.blurFilter?.provider = self.desaturateFilter
    }
    
    func updateImage() {
        jobIndex += 1
        let currentJobIndex: UInt = self.jobIndex
        
        // Grab these values while we're still on the main thread, since we could
        // conceivably get incomplete values by reading them in the background.
        let blurRadius: Float = self.blurRadiusSlider.floatValue
        let saturation: Float = self.saturationSlider.floatValue
        
        renderingQueue?.async {[weak self] in
            if currentJobIndex != self?.jobIndex {
                return
            }
            
            self?.blurFilter?.radius = blurRadius
            self?.desaturateFilter?.saturationFactor = saturation
            
            let texture = self?.blurFilter?.texture
            let image = NSImage.init(buffer: self?.blurFilter?.outputBuffer, texture: texture)
            
            DispatchQueue.main.async {[weak self] in
                self?.imageView.image = image
            }
        }
    }
}

