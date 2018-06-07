import UIKit
import AVFoundation
import CoreData
/*There's a standard QR reading app on github, I've used its code. */
class QRScannerController: UIViewController {
    var computers = [NSManagedObject]()
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?

    private let supportedCodeTypes = [AVMetadataObject.ObjectType.upce,
                                      AVMetadataObject.ObjectType.code39,
                                      AVMetadataObject.ObjectType.code39Mod43,
                                      AVMetadataObject.ObjectType.code93,
                                      AVMetadataObject.ObjectType.code128,
                                      AVMetadataObject.ObjectType.ean8,
                                      AVMetadataObject.ObjectType.ean13,
                                      AVMetadataObject.ObjectType.aztec,
                                      AVMetadataObject.ObjectType.pdf417,
                                      AVMetadataObject.ObjectType.itf14,
                                      AVMetadataObject.ObjectType.dataMatrix,
                                      AVMetadataObject.ObjectType.interleaved2of5,
                                      AVMetadataObject.ObjectType.qr]
   
    override func viewDidLoad() {
        super.viewDidLoad()


        // Get the back-facing camera for capturing videos
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back)
        guard let captureDevice = deviceDiscoverySession.devices.first else {
            print("Failed to get the camera device")
            return
        }

        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            // Set the input device on the capture session.
            captureSession.addInput(input)
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession.addOutput(captureMetadataOutput)
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
//            captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        //You can also limit the square which reads the QR by making a new imageview in the storyboard and then attaching videopreviewlayer to that.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds /*Attach that limited square frame here*/
        view.layer.addSublayer(videoPreviewLayer!)
        // Start video capture.
        captureSession.startRunning()
        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()
        if let qrCodeFrameView = qrCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
            qrCodeFrameView.layer.borderWidth = 2
            view.addSubview(qrCodeFrameView)
            view.bringSubview(toFront: qrCodeFrameView)
        }
    }

    func pairingMethod(_ decodedQR :String){
        var splitString = decodedQR.split(separator: "-")
        let seq_No:String = String(splitString[0])
        let username:String = String(splitString[1])
        let computerName:String = String(splitString[2])
        let KeyToSave:String = String(splitString[3])
        var phoneID = ""
        guard let ad = UIApplication.shared.delegate as? AppDelegate else {return}
        let managedContext = ad.persistentContainer.viewContext
        //check if computer exists in coredata database
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Computer")
        let predicate = NSPredicate(format: "computerID == %@", computerName)
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1 /*assuming unique computer IDs*/
        fetchRequest.includesSubentities = false

        do
        {
            let count = try managedContext.count(for: fetchRequest)
            if(count != 0)
            {
                // at least one matching object exists
                let alert = UIAlertController(title: "Device already paired", message: "computer with ID : \(String(describing: computerName)) is already paired", preferredStyle:.alert)
                let update = UIAlertAction(title: "re-pair", style: .default, handler: {action in
                    //do the keychain and seq_No update here.
                    print("updating ...")
                    //ask for touchID authenticaion
                    let touchMe = BiometricIDAuth()
                    touchMe.authenticateUser()
                        {
                            [weak self] message in
                            if let message = message {
                                print("invalid authentication during re-pairing")
                                let alertView = UIAlertController(title: "Error",
                                                                  message: message,
                                                                  preferredStyle: .alert)
                                let okAction = UIAlertAction(title: "Darn!", style: .default)
                                alertView.addAction(okAction)
                                self?.present(alertView, animated: true)
                            }
                            else
                            {   //modify the core data record and keychain entry
                                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Computer")

                                fetchRequest.predicate = NSPredicate(format: "computerID = %@",computerName)

                                do
                                {
                                    let results = try managedContext.fetch(fetchRequest) as? [NSManagedObject]
                                    if results?.count != 0
                                    { // Atleast one was returned

                                        // In my case, I only updated the first item in results, assuming unique computer IDs
                                        results![0].setValue(computerName, forKey: "computerID")

                                        //remove MK from keychain and then add new
                                        let removeSuccessful: Bool = KeychainWrapper.standard.removeObject(forKey: "\(computerName)-key")
                                        let saveSuccessful: Bool = KeychainWrapper.standard.set(KeyToSave, forKey: "\(computerName)-key")
                                    }
                                }
                                catch
                                {
                                    print("Fetch Failed: \(error)")
                                }

                                do
                                {
                                    try managedContext.save()
                                    self?.showResponseKey(KeyToSave: KeyToSave, seq_No: seq_No, computerName: computerName, username: username)
                                }
                                catch
                                {
                                    print("Updating CoreData Failed: \(error)")
                                }


                            }
                        }

                })
                let cancel = UIAlertAction(title: "Cancel", style: .destructive, handler:  { action in
                    self.captureSession.startRunning()
                    self.qrCodeFrameView?.frame = CGRect.zero
                })
                alert.addAction(update)
                alert.addAction(cancel)
                present(alert, animated: true, completion: nil )

            }
            else
            {
                // no matching object
                let PairingalertController = UIAlertController(title: "Pairing", message: "do you want to add this computer \n\(String(describing: computerName))", preferredStyle:.alert)
                let save = UIAlertAction(title: "Yes", style:  .default, handler: { action in
                    //directly add the computer data after touchID authentication
                    let entity = NSEntityDescription.entity(forEntityName: "Computer", in: managedContext)
                    let item = NSManagedObject(entity: entity!, insertInto: managedContext)
                    item.setValue(computerName, forKey: "computerID")

                    do{
                        self.computers.append(item)
                        try managedContext.save()
                        guard let saveSuccessful: Bool = KeychainWrapper.standard.set(KeyToSave, forKey: "\(computerName)-key")
                            else{return}
                        //show response key function
                    }catch let err as NSError{
                        print("Failed to save", err  )

                    }
                    self.showResponseKey(KeyToSave: KeyToSave, seq_No: seq_No, computerName: computerName, username: username)
                })
                let cancel = UIAlertAction(title: "No", style: .destructive, handler:  { action in
                    self.captureSession.startRunning()
                    self.qrCodeFrameView?.frame = CGRect.zero
                })
                PairingalertController.addAction(save)
                PairingalertController.addAction(cancel)
                self.present(PairingalertController, animated: true, completion: nil )
            }
        }
        catch let err as NSError
        {
            print("Failed to count",err)
        }
    }

    func showResponseKey(KeyToSave: String, seq_No:String, computerName:String, username:String )
    {
        var phoneID = ""
        //store phoneID in userdefaults
        let myString = UserDefaults.standard.string(forKey: "SYMCMobRecPhoneID")
        if ((myString) != nil)
        {
            print("phoneID already saved")
            phoneID = myString!//get the one already stored in user defaults
        }
        else
        {
            print("no phoneID saved currently")
            phoneID = randomString(length: 4)+"@"+String(format:"%08d", arc4random_uniform(100000000) )
            UserDefaults.standard.set(phoneID, forKey: "SYMCMobRecPhoneID")
        }

        //Show the response keyas a dialog that needs to be entered on PC to establish trust, with ONLY one phone.
        let encryptedMK = xor(text: String(describing:KeyToSave), cipher: String(describing:seq_No))
        let decryptedMK = xor(text: String(describing: encryptedMK), cipher: String(describing: seq_No))
        print(encryptedMK + "\t" + decryptedMK)
        var PoR = ""
        if(UInt(seq_No)! > 0){
             PoR = "Recovery"
        }
        else{
            PoR = "Pairing"
        }
        let alert2 = UIAlertController(title: "Response key", message: "Type the response key \n\(KeyToSave)-\(phoneID) \n\n encrypted:  \(encryptedMK) and decrypted:  \(decryptedMK) ", preferredStyle: .alert)
        let action2 = UIAlertAction(title: "done", style: .default, handler: {action in

            //finished dialog
            let alert = UIAlertController(title:"\(PoR) successful ", message: "", preferredStyle: UIAlertControllerStyle.alert)
            let saveAction = UIAlertAction(title: "", style: .default, handler: {action in
                self.captureSession.startRunning()
                self.qrCodeFrameView?.frame = CGRect.zero
                self.navigationController?.popViewController(animated: true)
                self.dismiss(animated: true, completion: nil)
            })

            var image = UIImage(named: "done")
            image = image?.withAlignmentRectInsets(UIEdgeInsets(top: 0, left:  -80, bottom: 0, right: 50))
            image = image?.withRenderingMode(.alwaysOriginal)
            saveAction.setValue(image!, forKey: "image")

            let action = UIAlertAction(title: "OK", style: .default, handler: {action in
                                                self.captureSession.startRunning()
                                                self.qrCodeFrameView?.frame = CGRect.zero
                                                self.navigationController?.popViewController(animated: true)
                                                self.dismiss(animated: true, completion: nil)
                            })

            alert.addAction(saveAction)
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        })
        alert2.addAction(action2)

        self.present(alert2, animated: true, completion: nil)
    }
    
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

    func xor(text:String, cipher:String) -> String {
        let textBytes = [UInt8](text.utf8)
        var cipherBytes = [UInt8](cipher.utf8)
        var encrypted = [UInt8]()

        if cipherBytes.count < textBytes.count {
            let cipherExtension = [UInt8](repeating: 0,count: (textBytes.count - cipherBytes.count + 1))
            cipherBytes.append(contentsOf:cipherExtension)
        }
        // encrypt bytes
        for (n,c) in textBytes.enumerated() {
           // print(n,"t",c,"t",cipherBytes[n],"t",c ^ cipherBytes[n])
            encrypted.append(c ^ cipherBytes[n+1])
        }
        return String(bytes: encrypted, encoding: String.Encoding.utf8)! // hello!!!

    }

    func recoveryMethod(_ decodedQR :String){
        //{ seq_No(>0) - username - machineID - MK/RandomKey }
        var splitString = decodedQR.split(separator: "-")
        let seq_No:String = String(splitString[0])
        let username:String = String(splitString[1])
        let computerName:String = String(splitString[2])
        let KeyToSave:String = String(splitString[3])

        guard let ad = UIApplication.shared.delegate as? AppDelegate else {return}
        let managedContext = ad.persistentContainer.viewContext
        //check if computer exists in database
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Computer")
        let predicate = NSPredicate(format: "computerID == %@", computerName)
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        fetchRequest.includesSubentities = false

        do{
            let count = try managedContext.count(for: fetchRequest)
            if(count == 0)
            {
                // no matching object
                let alert = UIAlertController(title: "Device Not found", message: "computer with ID : \(String(describing: computerName)) is not found in database", preferredStyle:.alert)
                let cancel = UIAlertAction(title: "OK", style: .destructive, handler:  { action in
                    self.captureSession.startRunning()
                    self.qrCodeFrameView?.frame = CGRect.zero
                })
                alert.addAction(cancel)
                present(alert, animated: true, completion: nil )
            }
            else
            {
                // at least one matching object exists
                let RecoveryAlertController = UIAlertController(title: "Recovery", message: "do you want to get recovery key for this computer \n\(String(describing: computerName))", preferredStyle:.alert)
                let save = UIAlertAction(title: "Yes", style:  .default, handler: { action in
                    let touchMe = BiometricIDAuth()
                    touchMe.authenticateUser()
                        {
                            [weak self] message in
                            if let message = message {
                                print("invalid authentication during re-pairing")
                                let alertView = UIAlertController(title: "Error",
                                                                  message: message,
                                                                  preferredStyle: .alert)
                                let okAction = UIAlertAction(title: "Darn!", style: .default)
                                alertView.addAction(okAction)
                                self?.present(alertView, animated: true)
                            }
                            else{
                                //show the recovery key as alert
                                let retrievedString: String? = KeychainWrapper.standard.string(forKey: "\(computerName)-key")

                                //TODO: XOR MK with seq_No
                                self?.showResponseKey(KeyToSave: KeyToSave, seq_No: seq_No, computerName: computerName, username: username)
                                //simply show the MK, without doing XOR with seq_No
                                let alert = UIAlertController(title: "Recovery Key", message: "computer : \(String(describing: computerName)) \n recovery key : \(String(describing: retrievedString)) ", preferredStyle:.alert)
                                let done = UIAlertAction(title: "Done", style: .destructive, handler:  { action in
                                    self?.captureSession.startRunning()
                                    self?.qrCodeFrameView?.frame = CGRect.zero
                                })
                                alert.addAction(done)
                                self?.present(alert, animated: true, completion: nil )

                                //Nothing to update inside mobile app
                            }
                    }
                })
                let cancel = UIAlertAction(title: "No", style: .destructive, handler:  { action in
                    self.captureSession.startRunning()
                    self.qrCodeFrameView?.frame = CGRect.zero
                })
                RecoveryAlertController.addAction(save)
                RecoveryAlertController.addAction(cancel)
                present(RecoveryAlertController, animated: true, completion: nil )
            }
        }
        catch let error as NSError {
            print("Could not fetch \(error), \(error.userInfo)")
        }
        captureSession.startRunning()
        self.qrCodeFrameView?.frame = CGRect.zero
    }

    func launchApp(decodedQR: String) {

        if presentedViewController != nil {
            return
        }

        captureSession.stopRunning()
        //check if QR code is properly structured with 3 dashes { seq_No - username - machineID - publickey/RandomKey }
        if((decodedQR.components(separatedBy: "-").count-1) == 3 ){
            captureSession.stopRunning()
            var splitString = decodedQR.split(separator: "-")
            let seq_No:UInt = UInt(splitString[0])!
            if ( seq_No == 0){
                self.pairingMethod(decodedQR)
            }
            else{
                self.recoveryMethod(decodedQR)
            }
        }
        else{
            print()
            let alert = UIAlertController(title: "Error", message: "QR is not properly structured", preferredStyle:.alert)
            let cancel = UIAlertAction(title: "OK", style: .destructive, handler:  { action in
                self.captureSession.startRunning()
                self.qrCodeFrameView?.frame = CGRect.zero
            })
            alert.addAction(cancel)
            present(alert, animated: true, completion: nil )
            return
        }


    }

}

extension QRScannerController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
//            messageLabel.text = "No QR code is detected"
            return
        }
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if supportedCodeTypes.contains(metadataObj.type) {
            // If the found metadata is equal to the QR code metadata (or barcode) then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            qrCodeFrameView?.transform = (qrCodeFrameView?.transform.scaledBy(x: 0.001, y: 0.001))!
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.3, options: .curveEaseInOut, animations: {
                self.qrCodeFrameView?.transform = CGAffineTransform.identity.scaledBy(x: 1.1, y: 1.1)
            }, completion: nil)

            if metadataObj.stringValue != nil {
                captureSession.stopRunning()
                launchApp(decodedQR: metadataObj.stringValue!)
            }
        }
    }
    
}
