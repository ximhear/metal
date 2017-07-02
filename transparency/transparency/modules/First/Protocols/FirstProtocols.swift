//
//  FirstProtocols.swift
//  transparency
//
//  Created by gzonelee on 12/06/17.
//  Copyright © 2017 G. All rights reserved.
//

import UIKit

protocol FirstViewProtocol: class {
    var presenter: FirstPresenterProtocol? { get set }
    /**
    * Add here your methods for communication PRESENTER -> VIEW
    */
}

protocol FirstWireFrameProtocol: class {
    static func createFirstModule() -> UINavigationController
    /**
    * Add here your methods for communication PRESENTER -> WIREFRAME
    */
}

protocol FirstPresenterProtocol: class {
    var view: FirstViewProtocol? { get set }
    var interactor: FirstInteractorInputProtocol? { get set }
    var wireFrame: FirstWireFrameProtocol? { get set }
    /**
    * Add here your methods for communication VIEW -> PRESENTER
    */
    func pushViewController(nc: UINavigationController)
}

protocol FirstInteractorOutputProtocol: class {
    /**
    * Add here your methods for communication INTERACTOR -> PRESENTER
    */
}

protocol FirstInteractorInputProtocol: class
{
    var presenter: FirstInteractorOutputProtocol? { get set }
    var APIDataManager: FirstAPIDataManagerInputProtocol? { get set }
    var localDatamanager: FirstLocalDataManagerInputProtocol? { get set }
    /**
    * Add here your methods for communication PRESENTER -> INTERACTOR
    */
}

protocol FirstDataManagerInputProtocol: class
{
    /**
    * Add here your methods for communication INTERACTOR -> DATAMANAGER
    */
}

protocol FirstAPIDataManagerInputProtocol: class
{
    /**
    * Add here your methods for communication INTERACTOR -> APIDATAMANAGER
    */
}

protocol FirstLocalDataManagerInputProtocol: class
{
    /**
    * Add here your methods for communication INTERACTOR -> LOCALDATAMANAGER
    */
}
