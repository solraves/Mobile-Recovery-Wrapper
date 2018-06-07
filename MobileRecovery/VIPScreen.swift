//
//  VIPScreen.swift
//  MobileRecovery
//
//  Created by Ravindra Chaturvedi on 23/05/18.
//  Copyright © 2018 Symantec. All rights reserved.
//

import Foundation
import UIKit

class VIPScreen :UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = "VIP Access"
        self.navigationItem.backBarButtonItem?.title = ""
        var phoneID = ""
        //store phoneID in userdefaults
        let myString = UserDefaults.standard.string(forKey: "SYMCMobRecPhoneID")
        if ((myString) != nil)
        {
            print("phoneID already saved")
            phoneID = myString!//get the one already stored in user defaults
            laPhoneID.text = phoneID
        }
        else
        {
            print("no phoneID saved currently")
            phoneID = randomString(length: 4)+"@"+String(format:"%08d", arc4random_uniform(100000000) )
            UserDefaults.standard.set(phoneID, forKey: "SYMCMobRecPhoneID")
            laPhoneID.text = phoneID
        }

    }
    @IBOutlet weak var laPhoneID: UILabel!

    func randomString(length: Int) -> String {

        let letters : NSString = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let len = UInt32(letters.length)

        var randomString = ""

        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }

        return randomString
    }
}
