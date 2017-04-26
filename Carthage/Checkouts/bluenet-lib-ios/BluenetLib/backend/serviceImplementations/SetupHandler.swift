//
//  SetupHandler.swift
//  BluenetLibIOS
//
//  Created by Alex de Mulder on 10/08/16.
//  Copyright © 2016 Alex de Mulder. All rights reserved.
//

import Foundation
import PromiseKit
import CoreBluetooth

open class SetupHandler {
    let bleManager : BleManager!
    var settings : BluenetSettings!
    let eventBus : EventBus!
    var deviceList : [String: AvailableDevice]!
    
    var unsubscribeNotificationCallback : voidPromiseCallback?
    
    var matchPacket : [UInt8] = [UInt8]()
    var validationResult : (Bool) -> Void = { _ in }
    var validationComplete = false
    var step = 0
    
    init (bleManager:BleManager, eventBus: EventBus, settings: BluenetSettings, deviceList: [String: AvailableDevice]) {
        self.bleManager = bleManager
        self.settings   = settings
        self.eventBus   = eventBus
        self.deviceList = deviceList
    }
    
    
    func handleSetupPhaseEncryption() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            self.bleManager.settings.disableEncryptionTemporarily()
            self.getSessionKey()
                .then{(key: [UInt8]) -> Promise<[UInt8]> in
                    self.eventBus.emit("setupProgress", 1);
                    self.bleManager.settings.loadSetupKey(key)
                    return self.getSessionNonce()
                }
                .then{(nonce: [UInt8]) -> Void in
                    self.eventBus.emit("setupProgress", 2)
                    self.bleManager.settings.setSessionNonce(nonce)
                    self.bleManager.settings.restoreEncryption()
                    fulfill()
                }
                .catch{(err: Error) -> Void in
                    self.bleManager.settings.restoreEncryption()
                    reject(err)
            }
        }
    }
    
    /**
     * This will handle the complete setup. We expect bonding has already been done by now.
     */
    open func setup(crownstoneId: UInt16, adminKey: String, memberKey: String, guestKey: String, meshAccessAddress: String, ibeaconUUID: String, ibeaconMajor: UInt16, ibeaconMinor: UInt16) -> Promise<Void> {
        self.step = 0
        return Promise<Void> { fulfill, reject in
            self.handleSetupPhaseEncryption()
                .then{(_) -> Promise<Void> in return self.setHighTX()}
                .then{(_) -> Promise<Void> in return self.setupNotifications()}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 3);  return self.writeCrownstoneId(crownstoneId)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 4);  return self.writeAdminKey(adminKey)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 5);  return self.writeMemberKey(memberKey)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 6);  return self.writeGuestKey(guestKey)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 7);  return self.writeMeshAccessAddress(meshAccessAddress)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 8);  return self.writeIBeaconUUID(ibeaconUUID)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 9);  return self.writeIBeaconMajor(ibeaconMajor)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 10); return self.writeIBeaconMinor(ibeaconMinor)}
                .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 11); return self.wrapUp()}
                .then{(_) -> Void in
                    LOG.info("BLUENET_LIB: Setup Finished")
                    self.eventBus.emit("setupProgress", 13);
                    self.bleManager.settings.exitSetup()
                    fulfill()
                }
                .catch{(err: Error) -> Void in
                    self.eventBus.emit("setupProgress", 0);
                    _ = self.clearNotifications()
                    self.bleManager.settings.exitSetup()
                    self.bleManager.settings.restoreEncryption()
                    _ = self.bleManager.disconnect()
                    reject(err)
                }
        }
    }
    
    
    
    func wrapUp() -> Promise<Void> {
        return self.clearNotifications()
            .then{(_) -> Promise<Void> in return self.finalizeSetup()}
            .then{(_) -> Promise<Void> in self.eventBus.emit("setupProgress", 12); return self.bleManager.disconnect()}
    }
    
    open func getSessionKey() -> Promise<[UInt8]> {
        LOG.info("getSessionKey")
        return self.bleManager.readCharacteristicWithoutEncryption(CSServices.SetupService, characteristic: SetupCharacteristics.SessionKey)
    }
        
    open func getSessionNonce() -> Promise<[UInt8]> {
        LOG.info("getSessionNonce")
        return self.bleManager.readCharacteristicWithoutEncryption(CSServices.SetupService, characteristic: SetupCharacteristics.SessionNonce)
    }
    
    
    open func putInDFU() -> Promise<Void> {
        LOG.info("put in DFU during setup.")
        let packet : [UInt8] = [66]
        self.bleManager.settings.disableEncryptionTemporarily()
        return Promise<Void> { fulfill, reject in
            self.bleManager.writeToCharacteristic(
                CSServices.SetupService,
                characteristicId: SetupCharacteristics.GoToDFU,
                data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
                type: CBCharacteristicWriteType.withResponse
            )
            .then{_ -> Void in
                self.bleManager.settings.restoreEncryption()
                fulfill()
            }
            .catch{(err: Error) -> Void in
                self.bleManager.settings.restoreEncryption()
                reject(err)
            }
        }
    }
    
    /**
     * Get the MAC address as a F3:D4:A1:CC:FF:32 String
     */
    open func getMACAddress() -> Promise<String> {
        return Promise<String> { fulfill, reject in
            self.bleManager.readCharacteristicWithoutEncryption(CSServices.SetupService, characteristic: SetupCharacteristics.MacAddress)
                .then{data -> Void in LOG.info("\(data)"); fulfill(Conversion.uint8_array_to_macAddress(data))}
                .catch{err in reject(err)}
        }
    }
    
    
    /**
     * This will handle the factory reset during setup mode.
     */
    open func factoryReset() -> Promise<Void> {
        return self.handleSetupPhaseEncryption()
            .then{(_) -> Promise<Void> in return self._factoryReset() }
            .then{(_) -> Void in _ = self.bleManager.disconnect() }
    }

    
    open func _factoryReset() -> Promise<Void> {
        LOG.info("factoryReset in setup")
        let packet = ControlPacket(type: .factory_RESET).getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.SetupService,
            characteristicId: SetupCharacteristics.Control,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    open func setHighTX() -> Promise<Void> {
        LOG.info("setHighTX")
        let packet = ControlPacket(type: .increase_TX).getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.SetupService,
            characteristicId: SetupCharacteristics.Control,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    open func writeCrownstoneId(_ id: UInt16) -> Promise<Void> {
        LOG.info("writeCrownstoneId")
        return self._writeAndVerify(.crownstone_IDENTIFIER, payload: Conversion.uint16_to_uint8_array(id))
    }
    open func writeAdminKey(_ key: String) -> Promise<Void> {
        LOG.info("writeAdminKey")
        return self._writeAndVerify(.admin_ENCRYPTION_KEY, payload: Conversion.ascii_or_hex_string_to_16_byte_array(key))
    }
    open func writeMemberKey(_ key: String) -> Promise<Void> {
        LOG.info("writeMemberKey")
        return self._writeAndVerify(.member_ENCRYPTION_KEY, payload: Conversion.ascii_or_hex_string_to_16_byte_array(key))
    }
    open func writeGuestKey(_ key: String) -> Promise<Void> {
        LOG.info("writeGuestKey")
        return self._writeAndVerify(.guest_ENCRYPTION_KEY, payload: Conversion.ascii_or_hex_string_to_16_byte_array(key))
    }
    open func writeMeshAccessAddress(_ address: String) -> Promise<Void> {
        LOG.info("writeMeshAccessAddress")
        return self._writeAndVerify(.mesh_ACCESS_ADDRESS, payload: Conversion.hex_string_to_uint8_array(address))
    }
    open func writeIBeaconUUID(_ uuid: String) -> Promise<Void> {
        LOG.info("writeIBeaconUUID")
        return self._writeAndVerify(.ibeacon_UUID, payload: Conversion.ibeaconUUIDString_to_reversed_uint8_array(uuid))
    }
    open func writeIBeaconMajor(_ major: UInt16) -> Promise<Void> {
        LOG.info("writeIBeaconMajor")
        return self._writeAndVerify(.ibeacon_MAJOR, payload: Conversion.uint16_to_uint8_array(major))
    }
    open func writeIBeaconMinor(_ minor: UInt16) -> Promise<Void> {
        LOG.info("writeIBeaconMinor")
        return self._writeAndVerify(.ibeacon_MINOR, payload: Conversion.uint16_to_uint8_array(minor))
    }
    open func finalizeSetup() -> Promise<Void> {
        LOG.info("finalizeSetup")
        let packet = ControlPacket(type: .validate_SETUP).getPacket()
        return self.bleManager.writeToCharacteristic(
            CSServices.SetupService,
            characteristicId: SetupCharacteristics.Control,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    func setupNotifications() -> Promise<Void> {
        // use the notification merger to handle the full packet once we have received it.
        let merger = NotificationMerger(callback: { data -> Void in
            do {
                // attempt to decrypt it
                let decryptedData = try EncryptionHandler.decrypt(Data(data), settings: self.bleManager.settings)
                if (self._checkMatch(input: decryptedData.bytes, target: self.matchPacket)) {
                    self.matchPacket = []
                    self.validationComplete = true
                    self.validationResult(true)
                }
            }
            catch _ {
                self.matchPacket = []
                self.validationComplete = true
                self.validationResult(false)
            }
        })
        
        let notificationCallback = {(data: Any) -> Void in
            if let castData = data as? Data {
                merger.merge(castData.bytes)
            }
        }
        
        return self.clearNotifications()
            .then{ _ in
                return self.bleManager.enableNotifications(
                    CSServices.SetupService,
                    characteristicId: SetupCharacteristics.ConfigRead,
                    callback: notificationCallback
                )
            }
            .then{ callback -> Void in self.unsubscribeNotificationCallback = callback }
    }
    
    func clearNotifications() -> Promise<Void> {
        return Promise<Void> { fulfill, reject in
            if (unsubscribeNotificationCallback != nil) {
                unsubscribeNotificationCallback!()
                    .then{ _ -> Void in
                        self.unsubscribeNotificationCallback = nil
                        fulfill()
                    }
                    .catch{ _ in }
            }
            else {
                fulfill()
            }
        }
    }
    
    // MARK : Support functions
    
    func _writeAndVerify(_ type: ConfigurationType, payload: [UInt8], iteration: UInt8 = 0) -> Promise<Void> {
        self.step += 1
        let initialPacket = WriteConfigPacket(type: type, payloadArray: payload).getPacket()
        return _writeConfigPacket(initialPacket)
            .then{_ -> Promise<Void> in self.bleManager.waitToWrite()}
            .then{_ -> Promise<Bool> in
                let packet = ReadConfigPacket(type: type).getPacket()
                // Make sure we first provide the fulfillment function before we ask for the notifications.
                return Promise<Bool> { fulfill, reject in
                    self.matchPacket = initialPacket
                    self.validationResult = fulfill
                    self.validationComplete = false
                    let stepId = self.step
                    
                    // fallback delay to cancel the wait for incoming notifications.
                    delay(2*timeoutDurations.waitForWrite, { _ in
                        if (self.validationComplete == false && self.step == stepId) {
                            self.validationResult = { _ in }
                            self.matchPacket = []
                            fulfill(false)
                        }
                    })
                    self._writeConfigPacket(packet).catch{ err in reject(err) }
                }
            }
            .then{ match -> Promise<Void> in
                if (match) {
                    LOG.info("validated.")
                    return Promise<Void> { fulfill, reject in fulfill() }
                }
                else {
                    if (iteration > 2) {
                        LOG.info("failed.")
                        return Promise<Void> { fulfill, reject in reject(BleError.CANNOT_WRITE_AND_VERIFY) }
                    }
                    LOG.info("retrying...")
                    return self._writeAndVerify(type, payload:payload, iteration: iteration+1)
                }
        }
    }
    
    func _writeConfigPacket(_ packet: [UInt8]) -> Promise<Void> {
        return self.bleManager.writeToCharacteristic(
            CSServices.SetupService,
            characteristicId: SetupCharacteristics.ConfigControl,
            data: Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count),
            type: CBCharacteristicWriteType.withResponse
        )
    }
    
    func _checkMatch(input: [UInt8], target: [UInt8]) -> Bool {
        let prefixLength = 4
        let dataLength = Int(Conversion.uint8_array_to_uint16([input[2],input[3]]))
        var match = (input.count >= prefixLength + dataLength && target.count >= prefixLength + dataLength)
        if (match == true) {
            for i in [Int](0...dataLength-1) {
                if (input[i+prefixLength] != target[i+prefixLength]){
                    match = false
                }
            }
        }
        return match
    }
    
    
    
    
    

}
