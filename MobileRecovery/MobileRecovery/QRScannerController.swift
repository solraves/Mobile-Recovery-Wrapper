import UIKit
import AVFoundation
import CoreData

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
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        // Start video capture.
        captureSession.startRunning()
        // Move the message label and top bar to the front
//        view.bringSubview(toFront: messageLabel)
        // Initialize QR Code Frame to highlight the QR code
        qrCodeFrameView = UIView()
        if let qrCodeFrameView = qrCodeFrameView {
            qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
            qrCodeFrameView.layer.borderWidth = 2
            view.addSubview(qrCodeFrameView)
            view.bringSubview(toFront: qrCodeFrameView)
        }
    }

    // MARK: - Helper methods
    func pairingMethod(_ decodedQR :String){
        var splitString = decodedQR.split(separator: "-")
        //let seq_No:UInt = UInt(splitString[0])!
        let username:String = String(splitString[1])
        let computerName:String = String(splitString[2])
        let KeyToSave:String = String(splitString[3])
        let algoType:String = String(splitString[4])

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
            if(count != 0){
                // at least one matching object exists
                let alert = UIAlertController(title: "Device already paired", message: "computer with ID : \(String(describing: computerName)) is already paired", preferredStyle:.alert)
                let update = UIAlertAction(title: "re-pair", style: .default, handler: {action in
                    //do the keychain and seq_No update here.
                    print("updating ...")
                    //TODO: ask for touchID authenticaion
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
                            {   //modify the core data record
                                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Computer")

                                fetchRequest.predicate = NSPredicate(format: "computerID = %@",computerName)

                                do {
                                    let results = try managedContext.fetch(fetchRequest) as? [NSManagedObject]
                                    if results?.count != 0 { // Atleast one was returned

                                        // In my case, I only updated the first item in results
                                        results![0].setValue(computerName, forKey: "computerID")
                                        //also update seq_No and all that nonsense.
                                        //remove from keychain and then add new
                                        let removeSuccessful: Bool = KeychainWrapper.standard.removeObject(forKey: "\(computerName)-key")
                                        let saveSuccessful: Bool = KeychainWrapper.standard.set(KeyToSave, forKey: "\(computerName)-key")
                                    }
                                } catch {
                                    print("Fetch Failed: \(error)")
                                }

                                do {
                                    try managedContext.save()
                                    let alert1 = UIAlertController(title: "Pairing Done", message: "Details updated", preferredStyle: .alert)
                                    let action1 = UIAlertAction(title: "OK", style: .default, handler: {action in
                                    self?.captureSession.startRunning()
                                    self?.qrCodeFrameView?.frame = CGRect.zero
                                    })
                                    let imgTitle = UIImage(named:"done.png")
                                    let imgViewTitle = UIImageView(frame: CGRect(x: 10, y: 20, width: 30, height: 30))
                                    imgViewTitle.image = imgTitle
                                    alert1.view.addSubview(imgViewTitle)
                                    alert1.addAction(action1)
                                    self?.present(alert1, animated: true, completion: nil)
                                }
                                catch {
                                    print("Saving Core Data Failed: \(error)")
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
            else{
                // no matching object
                //directly add the computer data after touchID authentication
                let entity = NSEntityDescription.entity(forEntityName: "Computer", in: managedContext)
                let item = NSManagedObject(entity: entity!, insertInto: managedContext)
                item.setValue(computerName, forKey: "computerID")

                do{
                    computers.append(item)
                    try managedContext.save()
                    guard let saveSuccessful: Bool = KeychainWrapper.standard.set(KeyToSave, forKey: "\(computerName)-key")
                        else{return}
                }catch let err as NSError{
                    print("Failed to save", err  )

                }
                //TODO: keychain update, seq_NO update and all that nonsense.
            }

        }catch let err as NSError{
            print("Failed to count",err)
        }
        //TODO: Show the response key that needs to be entered on PC to establish trust, with ONLY one phone.
        let alert = UIAlertController(title: "Pairing Done", message: "Pairing successful", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default, handler: nil)
        let imgTitle = UIImage(named:"done.png")
        let imgViewTitle = UIImageView(frame: CGRect(x: 10, y: 20, width: 30, height: 30))
        imgViewTitle.image = imgTitle
        alert.view.addSubview(imgViewTitle)
        alert.addAction(action)
        self.present(alert, animated: true, completion: nil)


        captureSession.startRunning()
        self.qrCodeFrameView?.frame = CGRect.zero
    }
    func recoveryMethod(_ decodedQR :String){
 //{ seq_No - username - machineID - publickey/RandomKey - (algorithmType) }
        var splitString = decodedQR.split(separator: "-")
        let seq_No:UInt = UInt(splitString[0])!
        let username:String = String(splitString[1])
        let computerName:String = String(splitString[2])
        let KeyToSave:String = String(splitString[3])
        let algoType:String = String(splitString[4])

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
            if(count == 0){
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
                            //show the recovery key as popup
                            //let retrievedString: String? = KeychainWrapper.standard.string(forKey: "\(computerName)-key")
                            //                let alert = UIAlertController(title: "Recovery Key", message: "computer with ID : \(String(describing: computerName)) found in database", preferredStyle:.alert)
                            //                let done = UIAlertAction(title: "Done", style: .destructive, handler:  { action in
                            //                    self.captureSession.startRunning()
                            //                    self.qrCodeFrameView?.frame = CGRect.zero
                            //                })
                            //                alert.addAction(done)
                            //                present(alert, animated: true, completion: nil )

                            //Nothing to update inside mobile app
                        }
                    }

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
        //check if QR code is properly structured with 4 dashes { seq_No - username - machineID - publickey/RandomKey - (algorithmType) }
        if((decodedQR.components(separatedBy: "-").count-1) == 4 ){
            var splitString = decodedQR.split(separator: "-")
            let seq_No:UInt = UInt(splitString[0])!
            //let username:String = String(splitString[1])
            let machineID:String = String(splitString[2])
           // let KeyToSave:String = String(splitString[3])
            //let algoType:String = String(splitString[4])

            if ( seq_No == 0){
                let PairingalertController = UIAlertController(title: "Pairing", message: "do you want to add this computer \n\(String(describing: machineID))", preferredStyle:.alert)
                let save = UIAlertAction(title: "Yes", style:  .default, handler: { action in
                    self.pairingMethod(decodedQR)
                })
                let cancel = UIAlertAction(title: "No", style: .destructive, handler:  { action in
                    self.captureSession.startRunning()
                    self.qrCodeFrameView?.frame = CGRect.zero
                })
                PairingalertController.addAction(save)
                PairingalertController.addAction(cancel)
                present(PairingalertController, animated: true, completion: nil )

            }
            else{
                let RecoveryAlertController = UIAlertController(title: "Recovery", message: "do you want to get recovery key for this computer \n\(String(describing: machineID))", preferredStyle:.alert)
                let save = UIAlertAction(title: "Yes", style:  .default, handler: { action in
                    self.recoveryMethod(decodedQR)
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
                launchApp(decodedQR: metadataObj.stringValue!)
            }
        }
    }
    
}
