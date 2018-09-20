//
//  Menu.swift
//  Menu
//
//  Created by gzonelee on 20/09/2018.
//  Copyright © 2018 gzonelee. All rights reserved.
//

import Foundation
import RealmSwift

class Menu: Object {
    @objc dynamic var created: Date = Date()
    @objc dynamic var modified: Date = Date()
    let items = List<MenuItem>()
    let history = List<MenuHistoryItem>()
}
