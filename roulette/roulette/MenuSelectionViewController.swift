//
//  MenuSelectionViewController.swift
//  Menu
//
//  Created by gzonelee on 20/09/2018.
//  Copyright © 2018 gzonelee. All rights reserved.
//

import UIKit
import RealmSwift

class MenuSelectionViewController: UITableViewController {

    var objects: Results<Menu>?

    var selectionChanged: (_ menu: Menu) -> Void = {_ in }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        navigationItem.leftBarButtonItem = editButtonItem
        
        do {
            let realm = try Realm()
            // Use the Realm as normal
            objects = realm.objects(Menu.self).sorted(byKeyPath: "modified", ascending: false).filter("items.@count > 1")
        } catch let error as NSError {
            // If the encryption key is wrong, `error` will say that it's an invalid database
            fatalError("Error opening realm: \(error)")
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem.init(title: "닫기", style: .plain, target: self, action: #selector(closeVC(_:)))

    }
    
    @objc func closeVC(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        if let menu = objects?[indexPath.row] {
            let a = menu.items.map { $0.title }.joined(separator: ",")
            cell.textLabel!.text = "\(menu.items.count) - \(a)"
        }
        else {
            cell.textLabel!.text = "XX"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let menu = objects?[indexPath.row] {
            selectionChanged(menu)
        }
    }
}
