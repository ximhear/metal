//
//  ViewController.swift
//  imageprocessing02
//
//  Created by LEE CHUL HYUN on 5/12/18.
//  Copyright © 2018 LEE CHUL HYUN. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var imageView:  UIImageView!
    @IBOutlet weak var blurRadiusSlider:  UISlider!
    @IBOutlet weak var saturationSlider:  UISlider!
    
    var context: GContext?
    var imageProvider: GTextureProvider?
    var desaturateFilter: GSaturationAdjustmentFilter?
    var blurFilter: GGaussianBlur2DFilter?
    var rotationFilter: GRotationFilter?
    
    var renderingQueue: DispatchQueue?
    var jobIndex: UInt = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.renderingQueue = DispatchQueue.init(label: "Rendering")
        
        buildFilterGraph()
        updateImage()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func blurChanged(_ sender: Any) {
        updateImage()
    }
    
    @IBAction func saturationChanged(_ sender: Any) {
        updateImage()
    }
    
    func buildFilterGraph() {
        self.context = GContext()
        
        self.imageProvider = MainBundleTextureProvider.init(imageName: "mandrill", context: self.context!)
        self.rotationFilter = GRotationFilter.init(context: self.context!)
        self.rotationFilter?.provider = self.imageProvider!
        

        self.desaturateFilter = GSaturationAdjustmentFilter.init(saturationFactor: self.saturationSlider.value, context: self.context!)
        self.desaturateFilter?.provider = self.rotationFilter
        
        self.blurFilter = GGaussianBlur2DFilter.init(radius: self.blurRadiusSlider.value, context: self.context!)
        self.blurFilter?.provider = self.desaturateFilter
    }
    
    func updateImage() {
        jobIndex += 1
        let currentJobIndex: UInt = self.jobIndex
        
        // Grab these values while we're still on the main thread, since we could
        // conceivably get incomplete values by reading them in the background.
        let blurRadius: Float = self.blurRadiusSlider.value
        let saturation: Float = self.saturationSlider.value
        
        renderingQueue?.async {[weak self] in
            if currentJobIndex != self?.jobIndex {
                return
            }
            
            self?.blurFilter?.radius = blurRadius
            self?.desaturateFilter?.saturationFactor = saturation
            
            let texture = self?.blurFilter?.texture
            let image = UIImage.init(texture: texture)
            
            DispatchQueue.main.async {[weak self] in
                self?.imageView.image = image
            }
        }
    }
}

