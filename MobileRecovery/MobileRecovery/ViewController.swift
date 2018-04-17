//
//  ViewController.swift
//  MobileRecovery
//
//  Created by Ravindra Chaturvedi on 14/04/18.
//  Copyright © 2018 Symantec. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UITableViewController {

    var computers = [NSManagedObject]()
    let cellID = "cellID"
   // let refreshControl = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl?.addTarget(self, action: Selector(("refresh:")), for: UIControlEvents.valueChanged)
        tableView.addSubview(refreshControl!) // not required when using UITableViewController

        let newBtn = UIBarButtonItem(title: "clear", style: .plain, target: self, action: #selector(clearData))
        self.navigationItem.leftItemsSupplementBackButton = true
        self.navigationItem.leftBarButtonItem = newBtn//self.navigationItem.leftBarButtonItems = [newBtn,anotherBtn]

    }
   @objc func refresh(sender:AnyObject) {
        self.tableView.reloadData()
    refreshControl?.endRefreshing()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let ad = UIApplication.shared.delegate as? AppDelegate else {return}
        let contexta = ad.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Computer")
        do{
             computers = try contexta.fetch(fetchRequest)
        }catch let err as NSError{
            print("Failed to fetch items",err)
        }
        self.tableView.reloadData()
    }
    @objc func clearData(){
        self.deleteAllData(entity :"Computer")
        self.tableView.reloadData()
    }
    func deleteAllData(entity: String)
    {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entity)
        fetchRequest.returnsObjectsAsFaults = false

        do
        {
            let results = try managedContext.fetch(fetchRequest)
            for managedObject in results
            {
                let managedObjectData:NSManagedObject = managedObject
                managedContext.delete(managedObjectData)
            }
            try managedContext.save()
        } catch let error as NSError {
            print("Detele all data in \(entity) error : \(error) \(error.userInfo)")
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return computers.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cellID", for:  indexPath)
        let item = computers[indexPath.row]
        cell.textLabel?.text = item.value(forKey: "computerID") as? String
        return cell
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else {return}
        computers.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        //remove also from core data
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let managedContext = appDelegate.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Computer")
        fetchRequest.returnsObjectsAsFaults = false

        do
        {
            let results = try managedContext.fetch(fetchRequest)
            let managedObjectData:NSManagedObject = results[indexPath.row]
            managedContext.delete(managedObjectData)

            try managedContext.save()
              print("Deleted data at row \(indexPath.row) ")
        } catch let error as NSError {
            print("Detele all data in Computers error : \(error) \(error.userInfo)")
        }
    }


    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "segue1" {
            if let destination = segue.destination as? QRScannerController {
                destination.computers = self.computers
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewControllerB = segue.destination as? QRScannerController {
            viewControllerB.callback = { message in
                self.computers = viewControllerB.computers
            }
        }
    }
}