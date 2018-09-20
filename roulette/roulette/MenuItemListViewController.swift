//
//  MenuItemListViewController.swift
//  Menu
//
//  Created by gzonelee on 20/09/2018.
//  Copyright © 2018 gzonelee. All rights reserved.
//

import UIKit
import RealmSwift

class MenuItemListViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!


    func configureView() {
        // Update the user interface for the detail item.
        if let _ = menu {
            if let tableView = tableView {
                tableView.reloadData()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        configureView()
        
        let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(insertNewObject(_:)))
        navigationItem.rightBarButtonItems = [addButton, editButtonItem]
    }

    var menu: Menu? {
        didSet {
            // Update the view.
            configureView()
        }
    }

    @objc
    func insertNewObject(_ sender: Any) {

        let alert = UIAlertController(title: "Item", message: "Please input text", preferredStyle: UIAlertController.Style.alert)
        
        alert.addTextField { (textField) in
            textField.placeholder = "Enter item"
        }

        let add = UIAlertAction(title: "Add", style: .default) { (alertAction) in
            if let text = alert.textFields?[0].text, text.count > 0 {
                self.add(title: text)
            }
        }

        let cancel = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(add)
        alert.addAction(cancel)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func add(title: String) {

        let count = menu?.items.count ?? 0
        do {
            let realm = try Realm()
            
            try realm.write {
                let item = MenuItem()
                item.title = title
                menu?.items.append(item)
                
                let historyItem = MenuHistoryItem()
                historyItem.title = menu?.items.last?.title ?? ""
                menu?.history.append(historyItem)
            }
        } catch let error as NSError {
            // If the encryption key is wrong, `error` will say that it's an invalid database
            fatalError("Error opening realm: \(error)")
        }
        
        let indexPath = IndexPath(row: count, section: 0)
        tableView.insertRows(at: [indexPath], with: .automatic)
    }

    // MARK: - Segues
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showHistory" {
            let controller = segue.destination as! HistoryTableViewController
            controller.menu = menu
            controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
            controller.navigationItem.leftItemsSupplementBackButton = true
        }
    }
 
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
    }
}

extension MenuItemListViewController: UITableViewDelegate, UITableViewDataSource {
 
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return menu?.items.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        if let menu = menu?.items[indexPath.row] {
            cell.textLabel!.text = menu.title
        }
        else {
            cell.textLabel!.text = "XX"
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let menu = menu?.items[indexPath.row] {
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

    func tableView(_ tableView: UITableView, willBeginEditingRowAt indexPath: IndexPath) {
        super.setEditing(true, animated: true)
    }
    
    func tableView(_ tableView: UITableView, didEndEditingRowAt indexPath: IndexPath?) {
        super.setEditing(false, animated: true)
    }

}

