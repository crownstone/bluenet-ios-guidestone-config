//
//  ViewController.swift
//  CSiBeaconDev
//
//  Created by Alex de Mulder on 22/11/2016.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import UIKit
import BluenetLib
import SwiftyJSON
import CoreBluetooth
import PromiseKit


class ViewController: UIViewController {
    var target : String? = nil
    var targetValidatedStoneHandle : String? = nil
    var targetSetupHandle : String? = nil
    
    var lastSetup = Date().timeIntervalSince1970
    var lastValidatedStone = Date().timeIntervalSince1970
    
    var bluenet : Bluenet!
    var bluenetLocalization : BluenetLocalization!
    
    let adminKey  = "00AskAdminKeyIOS"
    let memberKey = "0AskMemberKeyIOS"
    let guestKey  = "00AskGuestKeyIOS"
    
    func checkIbeaconInput() -> Bool {
        if (uuidInput.text != nil && majorInput != nil && minorInput != nil) {
            if (uuidInput.text!.characters.count != 36) {
                progress.text = "UUID needs to be 36 characters, like 'b843423e-e175-4af0-a2e4-31e32f729a8a'"
                return false
            }
            let majorInputInt = UInt16(majorInput.text!)
            if (majorInputInt == nil) {
                progress.text = "major must be a uint16 number"
                return false
            }
            let minorInputInt = UInt16(minorInput.text!)
            if (minorInputInt == nil) {
                progress.text = "minor must be a uint16 number"
                return false
            }
            return true
        }
        else {
            progress.text = "UUID, major and minor have to be entered"
            return false
        }
    }
    
    @IBAction func selectNearestSetup(_ sender: Any) {
        if (targetSetupHandle != nil) {
            target = targetSetupHandle!
            progress.text = "target set to setupStone"
        }
        else {
            progress.text = "no target"
        }
    }
    @IBAction func selectNearestGuide(_ sender: Any) {
        if (targetValidatedStoneHandle != nil) {
            target = targetValidatedStoneHandle!
            progress.text = "target set to nearestValidatedStone"
        }
        else {
            progress.text = "nothing selected"
        }
        
    }
    @IBAction func setupButton(_ sender: Any) {
        if (target != nil) {
            if (checkIbeaconInput()) {
                let majorInputInt = UInt16(majorInput.text!)
                let minorInputInt = UInt16(minorInput.text!)
                self.setupCrownstone(target!, ibeaconUUID: uuidInput.text!, major: majorInputInt!, minor: minorInputInt!)
                progress.text = "Starting setup"
            }
        }
        else {
            progress.text = "nothing selected"
        }
    }
    @IBAction func recoverButton(_ sender: Any) {
        if (target != nil) {
            self.bluenet.control.recoverByFactoryReset(target!)
                .then{_    in self.progress.text = "done"}
                .catch{err in self.progress.text = "\(err)"}
            progress.text = "start recovery"
        }
        else {
            progress.text = "nothing selected"
        }
    }
    @IBAction func updateButton(_ sender: Any) {
        if (target != nil) {
            if (checkIbeaconInput()) {
                let majorInputInt = UInt16(majorInput.text!)
                let minorInputInt = UInt16(minorInput.text!)
                
                progress.text = "Starting update"
                self.bluenet.isReady() // first check if the bluenet lib is ready before using it for BLE things.
                    .then{_ -> Promise<Void> in return self.bluenet.connect(self.target!)} // once the lib is ready, start scanning
                    .then{_ -> Promise<Void> in self.bluenet.config.setIBeaconUUID(self.uuidInput.text!)}
                    .then{_ -> Promise<Void> in self.bluenet.waitToWrite(0)}
                    .then{_ -> Promise<Void> in self.bluenet.config.setIBeaconMajor(majorInputInt!)}
                    .then{_ -> Promise<Void> in self.bluenet.waitToWrite(0)}
                    .then{_ -> Promise<Void> in self.bluenet.config.setIBeaconMinor(minorInputInt!)}
                    .then{_ -> Promise<Void> in
                        self.progress.text = "Restarting Guidestone..."
                        return self.bluenet.control.reset()
                    }
                    .then{_ in self.bluenet.waitToWrite(0)}
                    .then{_ -> Void in
                        self.progress.text = "Update Complete."
                    }
                    .catch{err in
                        self.progress.text = "Error in update"
                        print("end of line \(err)")
                        _ = self.bluenet.disconnect()
                }
            }
        }
        else {
            progress.text = "nothing selected"
        }
    }
    
    @IBOutlet weak var uuidInput: UITextField!
    @IBOutlet weak var majorInput: UITextField!
    @IBOutlet weak var minorInput: UITextField!
    @IBOutlet weak var progress: UITextView!
    
    @IBOutlet weak var nearLabel: UILabel!
    @IBOutlet weak var setupLabel: UILabel!
    @IBOutlet weak var targetLabel: UILabel!
    
    func _evalLabels() {
        let now = Date().timeIntervalSince1970
        if (now - lastSetup > 4) {
            targetSetupHandle = nil
            setupLabel.text = "None found"
        }
        if (now - lastValidatedStone > 4) {
            targetValidatedStoneHandle = nil
            nearLabel.text = "None found"
        }
    }
    func startLoop() {
        delay(0.5, { _ in
            self._evalLabels()
            self.startLoop()
        })
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // remove keyboard on tap
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(ViewController.dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        self.startLoop()
        
        // important, set the viewcontroller and the appname in the library so we can trigger
        // alerts for bluetooth and navigation usage.
        BluenetLib.setBluenetGlobals(viewController: self, appName: "Crownstone")
        self.bluenet = Bluenet();
        self.bluenetLocalization = BluenetLocalization();
        // Do any additional setup after loading the view, typically from a nib.
        self.bluenet.setSettings(encryptionEnabled: true, adminKey: adminKey, memberKey: memberKey, guestKey: guestKey, referenceId:"ASK")
        
        self.bluenetLocalization.clearTrackedBeacons()
        _ = self.bluenet.isReady()
            .then{_ in self.bluenet.startScanningForCrownstones()}
        
        
        _ = self.bluenet.on("setupProgress", {data -> Void in
            if let castData = data as? Int {
                self.progress.text = "setupProgress \(castData)"
            }
        })
        _ = self.bluenet.on("nearestSetupCrownstone", {data -> Void in
            if let castData = data as? NearestItem {
                self.lastSetup = Date().timeIntervalSince1970
                
                let dict = castData.getDictionary()
                self.targetSetupHandle = dict["handle"] as? String
                self.setupLabel.text = "\(dict["name"]!) : \(dict["rssi"]!)"
                self._evalLabels()
            }
        })
        _ = self.bluenet.on("nearestVerifiedCrownstone", {data -> Void in
            if let castData = data as? NearestItem {
                self.lastValidatedStone = Date().timeIntervalSince1970
                
                let dict = castData.getDictionary()
                self.targetValidatedStoneHandle = dict["handle"] as? String
                self.nearLabel.text = "\(dict["name"]!) : \(dict["rssi"]!)"
                self._evalLabels()
            }
        })
        
        _ = self.bluenet.on("advertisementData", {data -> Void in
            if let castData = data as? Advertisement {
                let dict = castData.getDictionary()
                
                if (self.target == dict["handle"] as? String) {
                    self.targetLabel.text = "\(dict["name"]!) : \(dict["rssi"]!)"
                }
            }
        })
        
        
    }
    
    func setupCrownstone(_ uuid: String, ibeaconUUID: String, major: UInt16, minor: UInt16) {
        self.bluenet.isReady() // first check if the bluenet lib is ready before using it for BLE things.
            .then{_ in return self.bluenet.connect(uuid)} // once the lib is ready, start scanning
            .then{_ in self.bluenet.setup.setup(crownstoneId: 32, adminKey: self.adminKey, memberKey: self.memberKey, guestKey: self.guestKey, meshAccessAddress: "4fd45905", ibeaconUUID: ibeaconUUID, ibeaconMajor: major, ibeaconMinor: minor)} // once the lib is ready, start scanning
            .then{_ -> Void in
                self.progress.text = "SETUP COMPLETE"
                print("DONE")
            }
            .catch{err in
                print("end of line \(err)")
                _ = self.bluenet.disconnect()
        }
    }
    
    //Calls this function when the tap is recognized.
    func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

