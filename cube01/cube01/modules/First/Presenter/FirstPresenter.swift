//
//  FirstPresenter.swift
//  cube01
//
//  Created by gzonelee on 12/06/17.
//  Copyright © 2017 G. All rights reserved.
//

import Foundation
import UIKit

class FirstPresenter: FirstPresenterProtocol, FirstInteractorOutputProtocol {
    weak var view: FirstViewProtocol?
    var interactor: FirstInteractorInputProtocol?
    var wireFrame: FirstWireFrameProtocol?

    init() {}
    
    func pushViewController(nc: UINavigationController) {
        
    }
}
