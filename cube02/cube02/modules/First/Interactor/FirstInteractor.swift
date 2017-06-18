//
//  FirstInteractor.swift
//  cube02
//
//  Created by gzonelee on 12/06/17.
//  Copyright © 2017 G. All rights reserved.
//

import Foundation

class FirstInteractor: FirstInteractorInputProtocol {

    weak var presenter: FirstInteractorOutputProtocol?
    var APIDataManager: FirstAPIDataManagerInputProtocol?
    var localDatamanager: FirstLocalDataManagerInputProtocol?

    init() {}
}
