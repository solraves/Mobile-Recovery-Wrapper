//
//  BluetoothController.swift
//  MobileRecovery
//
//  Created by Ravindra Chaturvedi on 19/04/18.
//  Copyright © 2018 Symantec. All rights reserved.
//
import UIKit
import Foundation
import Bluepeer
import xaphodObjCUtils
import CoreBluetooth

class BluetoothController: UIViewController {
    let bluepeer = BluepeerObject.init(serviceType: "serviceTypeStr", displayName: "SEEMA", queue: nil, serverPort: XaphodUtils.getFreeTCPPort(), interfaces: BluepeerInterfaces.notWifi, bluetoothBlock: nil)!
    @IBAction func bluetoothAction(_ sender: Any) {
        print(bluepeer.bluetoothState.rawValue )
        if (bluepeer.bluetoothState == BluetoothState.poweredOff)
        {
            let alert = UIAlertController.init(title: "Bluetooth is Off", message: "This app can use both Bluetooth and WiFi. Bluetooth is almost always required. Please turn on Bluetooth now.", preferredStyle: .alert)
            alert.addAction(UIAlertAction.init(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction.init(title: "Open Settings", style: .default, handler: { (_) in
                let url = URL(string: "App-Prefs:root=Bluetooth")
                let app = UIApplication.shared
                app.openURL(url!)
                //UIApplication.shared.openURL(NSURL.init(string: UIApplicationOpenSettingsURLString)! as URL)
            }))
            self.present(alert, animated: true, completion: nil)
        }

     //   bluepeer.sessionDelegate = self
        bluepeer.dataDelegate = self as? BluepeerDataDelegate
        bluepeer.startAdvertising(.server, customData: ["key":"1234566"])
        print(bluepeer.connectedPeers())
       // bluepeer.sendData(["RAvi"], toRole: .server)


    }
    override func viewDidLoad() {
        super.viewDidLoad()
    }



}
//

