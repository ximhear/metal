//
//  FirstWireFrame.swift
//  cube02
//
//  Created by gzonelee on 12/06/17.
//  Copyright © 2017 G. All rights reserved.
//

import UIKit

class FirstWireFrame: FirstWireFrameProtocol {

    static func createFirstModule() -> UINavigationController {
        
        // Generating module components
        let viewController = storyboard.instantiateViewController(withIdentifier: "FirstViewController")
        if let view = viewController as? FirstViewController {
            let presenter: FirstPresenterProtocol & FirstInteractorOutputProtocol = FirstPresenter()
            let interactor: FirstInteractorInputProtocol = FirstInteractor()
            let APIDataManager: FirstAPIDataManagerInputProtocol = FirstAPIDataManager()
            let localDataManager: FirstLocalDataManagerInputProtocol = FirstLocalDataManager()
            let wireFrame: FirstWireFrameProtocol = FirstWireFrame()
            
            // Connecting
            view.presenter = presenter
            presenter.view = view
            presenter.wireFrame = wireFrame
            presenter.interactor = interactor
            interactor.presenter = presenter
            interactor.APIDataManager = APIDataManager
            interactor.localDatamanager = localDataManager
            
        }
        let nav:UINavigationController = UINavigationController(rootViewController: viewController)
        nav.setNavigationBarHidden(false, animated: false)
        return nav
    }
    
    static var storyboard: UIStoryboard {
        return UIStoryboard(name: "Main", bundle: Bundle.main)
    }
}
