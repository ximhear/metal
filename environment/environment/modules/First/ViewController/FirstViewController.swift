//
//  FirstViewController.swift
//  environment
//
//  Created by gzonelee on 12/06/17.
//  Copyright © 2017 G. All rights reserved.
//

import Foundation
import UIKit

class FirstViewController: UIViewController, FirstViewProtocol {
    var presenter: FirstPresenterProtocol?
    
    @IBAction func nextClicked(_ sender : Any) {
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let vc = sb.instantiateViewController(withIdentifier: "ViewController") as! ViewController
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
