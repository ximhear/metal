//
//  FirstViewController.swift
//  environment
//
//  Created by gzonelee on 12/06/17.
//  Copyright © 2017 G. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {
    var className: String {
        return NSStringFromClass(self.classForCoder).components(separatedBy: ".").last!
    }
}
class FirstViewController: UIViewController, FirstViewProtocol {
    var presenter: FirstPresenterProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.className
        self.view.backgroundColor = UIColor.red
    }
    
    @IBAction func nextClicked(_ sender : Any) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "ViewController") as! ViewController
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        SBLog.debug()
        super.viewWillAppear(animated)
        
//        self.navigationController?.navigationBar.setBackgroundImage(nil, for: UIBarMetrics.default)
//        self.navigationController?.navigationBar.shadowImage = nil
//        self.navigationController?.navigationBar.tintColor = nil
//        self.navigationController?.navigationBar.isTranslucent = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        SBLog.debug()
        super.viewDidAppear(animated)
    }
}

