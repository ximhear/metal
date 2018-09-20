//
//  MenuListViewController.swift
//  Menu
//
//  Created by gzonelee on 20/09/2018.
//  Copyright © 2018 gzonelee. All rights reserved.
//

import UIKit
import RealmSwift

class MenuListViewController: UITableViewController {

    var objects: Results<Menu>?


    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        navigationItem.leftBarButtonItem = editButtonItem
        
        do {
            let realm = try Realm()
            // Use the Realm as normal
            objects = realm.objects(Menu.self).sorted(byKeyPath: "modified", ascending: false)
        } catch let error as NSError {
            // If the encryption key is wrong, `error` will say that it's an invalid database
            fatalError("Error opening realm: \(error)")
        }

        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItems = [addButton, editButtonItem]
        
        navigationItem.leftBarButtonItem = UIBarButtonItem.init(title: "닫기", style: .plain, target: self, action: #selector(closeVC(_:)))
    }

    @objc func closeVC(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc
    func insertNewObject(_ sender: Any) {

        do {
            let realm = try Realm()

            try realm.write {
                let menu = Menu()
                realm.add(menu)
            }
        } catch let error as NSError {
            // If the encryption key is wrong, `error` will say that it's an invalid database
            fatalError("Error opening realm: \(error)")
        }

        let indexPath = IndexPath(row: 0, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
        
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        performSegue(withIdentifier: "showDetail", sender: nil)
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let menu = objects?[indexPath.row]
                let controller = segue.destination as! MenuItemListViewController
                controller.menu = menu
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
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
            cell.textLabel!.text = menu.modified.localFormatString()
        }
        else {
            cell.textLabel!.text = "XX"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let menu = objects?[indexPath.row] {
                do {
                    let realm = try Realm()
                    try realm.write {
                        realm.delete(menu)
                    }
                } catch let error as NSError {
                    // If the encryption key is wrong, `error` will say that it's an invalid database
                    fatalError("Error opening realm: \(error)")
                }
            }
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }


}

extension Date {
    public func localFormatString() -> String {
        let locale = Locale.current
        let dateFormatter = DateFormatter()
        dateFormatter.locale = locale
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.timeZone = TimeZone.current
        
        return dateFormatter.string(from: self)
    }
}
