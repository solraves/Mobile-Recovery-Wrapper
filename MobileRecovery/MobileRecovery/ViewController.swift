//
//  ViewController.swift
//  MobileRecovery
//
//  Created by Ravindra Chaturvedi on 14/04/18.
//  Copyright © 2018 Symantec. All rights reserved.
//

import UIKit
import CoreData
import LocalAuthentication
import Bluepeer
import xaphodObjCUtils

class ViewController: UITableViewController {

    var computers = [NSManagedObject]()
    let cellID = "cellID"
    let bluepeer = BluepeerObject.init(serviceType: "serviceTypeStr", displayName: "SEEMA", queue: nil, serverPort: XaphodUtils.getFreeTCPPort(), interfaces: BluepeerInterfaces.notWifi, bluetoothBlock: nil)!


    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellID)

        self.refreshControl = UIRefreshControl()
        refreshControl?.attributedTitle = NSAttributedString(string: "")
        refreshControl?.addTarget(self, action: #selector(refresh(sender:)), for: UIControlEvents.valueChanged)

        let newBtn = UIBarButtonItem(title: "clear", style: .plain, target: self, action: #selector(clearData))
        self.navigationItem.leftItemsSupplementBackButton = true
        //let newBtn2 = UIBarButtonItem(title: "BB", style: .plain, target: self, action: #selector(bluetoothFunction))
        //self.navigationItem.leftItemsSupplementBackButton = true
        self.navigationItem.leftBarButtonItem = newBtn
      //  self.navigationItem.leftBarButtonItems = [newBtn,newBtn2]

    }
   @objc func refresh(sender:AnyObject) {
        self.tableView.reloadData()
        self.refreshControl?.endRefreshing()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        guard let ad = UIApplication.shared.delegate as? AppDelegate else {return}
        let managedContext = ad.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "Computer")
        do{
             computers = try managedContext.fetch(fetchRequest)
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
        let touchMe = BiometricIDAuth()
        touchMe.authenticateUser() { [weak self] message in
        if let message = message {
            // if the completion is not nil show an alert
            print("invalid authentication")
            let alertView = UIAlertController(title: "Error",
                                              message: message,
                                              preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Darn!", style: .default)
            alertView.addAction(okAction)
            self?.present(alertView, animated: true)
        } else {
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
                    let computerName = String(describing : managedObjectData.value(forKey: "computerID"))

                    guard let removeSuccessful: Bool = KeychainWrapper.standard.removeObject(forKey: "\(String(describing: managedObjectData.value(forKey: "computerID")))-key") else{
                        print("can't delete keychain data for computerID : \(String(describing: managedObjectData.value(forKey: "computerID")))")
                    }
                    guard let removeSuccessful2: Bool = KeychainWrapper.standard.removeObject(forKey: "\(computerName)-key") else{
                        print("can't delete 2nd time keychain data for computerID : \(computerName)")
                    }
                }
                try managedContext.save()
            } catch let error as NSError {
                print("Detele all data in \(entity) error : \(error) \(error.userInfo)")
            }
            self?.tableView.reloadData()
            }
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
        let touchMe = BiometricIDAuth()
        touchMe.authenticateUser()
        {
            [weak self] message in
            if let message = message {
                print("invalid authentication")
                let alertView = UIAlertController(title: "Error",
                                                  message: message,
                                                  preferredStyle: .alert)
                let okAction = UIAlertAction(title: "Darn!", style: .default)
                alertView.addAction(okAction)
                self?.present(alertView, animated: true)
            }
            else
            {
                self?.computers.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .automatic)
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
                    let computerName = String(describing : managedObjectData.value(forKey: "computerID"))

                    guard let removeSuccessful: Bool = KeychainWrapper.standard.removeObject(forKey: "\(String(describing: managedObjectData.value(forKey: "computerID")))-key") else{
                        print("can't delete keychain data for computerID : \(String(describing: managedObjectData.value(forKey: "computerID")))")
                    }
                    guard let removeSuccessful2: Bool = KeychainWrapper.standard.removeObject(forKey: "\(computerName)-key") else{
                        print("can't delete 2nd time keychain data for computerID : \(computerName)")}
                } catch let error as NSError {
                    print("Detele all data in Computers error : \(error) \(error.userInfo)")
                }
            }

        }

    }


    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "segue1" {
            if let destination = segue.destination as? QRScannerController {
                destination.computers = self.computers
            }
        }
    }

}
