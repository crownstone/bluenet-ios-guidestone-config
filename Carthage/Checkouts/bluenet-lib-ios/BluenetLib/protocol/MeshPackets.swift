//
//  MeshPackets.swift
//  BluenetLib
//
//  Created by Alex de Mulder on 03/02/2017.
//  Copyright © 2017 Alex de Mulder. All rights reserved.
//

import Foundation

class MeshControlPacket {
    var channel : MeshChannel!
    var length  : UInt16
    var payload : [UInt8]!
    
    init(channel: MeshChannel, payload: [UInt8]) {
        self.channel = channel
        self.length = NSNumber(value: payload.count).uint16Value
        self.payload = payload
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.channel.rawValue)
        arr.append(0) // reserved
        arr += Conversion.uint16_to_uint8_array(self.length)
        arr += self.payload
        return arr
    }
}


class StoneKeepAlivePacket {
    var crownstoneId  : UInt16 = 0
    var actionAndState : UInt8 = 0
    
    convenience init(crownstoneId: UInt16, action: Bool, state: Float) {
        let switchState = NSNumber(value: min(1,max(0,state))*100).uint8Value
        self.init(crownstoneId: crownstoneId, action: action, state: switchState)
    }
    
    convenience init(crownstoneId: UInt16, action: Bool, state: UInt8) {
        var combinedState = state
        if (action == false) {
            combinedState = 255
        }
        self.init(crownstoneId: crownstoneId, actionAndState: combinedState)
    }
    
    init(crownstoneId: UInt16, actionAndState: UInt8) {
        self.crownstoneId = crownstoneId
        self.actionAndState = actionAndState
    }
    
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.crownstoneId)
        arr.append(self.actionAndState)
        return arr
    }
}


class MeshKeepAlivePacket {
    var timeout : UInt16 = 0
    var size    : UInt8  = 0
    var packets : [StoneKeepAlivePacket]!
    
    init(timeout: UInt16, packets: [StoneKeepAlivePacket]) {
        self.timeout = timeout
        self.size = NSNumber(value: packets.count).uint8Value
        self.packets = packets
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.timeout)
        arr.append(self.size)
        for packet in self.packets {
            arr += packet.getPacket()
        }
        return arr
    }
}

class MeshCommandPacket {
    var messageType    : MeshCommandType!
    var idCounter      : UInt8 = 0
    var crownstoneIds  : [UInt16]!
    var payload : [UInt8]!
    
    
    
    init(messageType: MeshCommandType, crownstoneIds: [UInt16], payload: [UInt8]) {
        self.messageType = messageType
        self.crownstoneIds = crownstoneIds
        self.payload = payload
        self.idCounter = NSNumber(value: crownstoneIds.count).uint8Value
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.messageType.rawValue)
        arr.append(self.idCounter)
        arr += Conversion.uint16_array_to_uint8_array(self.crownstoneIds)
        arr += self.payload
        
        return arr
    }
}

class StoneSwitchPacket {
    var timeout : UInt16 = 0
    var crownstoneId : UInt16
    var state   : UInt8
    var intent  : UInt8
    
    convenience init(crownstoneId: UInt16, state: UInt8, intent: UInt8) {
        self.init(crownstoneId: crownstoneId, state: state, timeout:0, intent: intent)
    }
    
    convenience init(crownstoneId: UInt16, state: Float, intent: UInt8) {
        self.init(crownstoneId: crownstoneId, state: state, timeout:0, intent: intent)
    }
    
    convenience init(crownstoneId: UInt16, state: Float, timeout: UInt16, intent: UInt8) {
        let switchState = NSNumber(value: min(1,max(0,state))*100).uint8Value
        self.init(crownstoneId: crownstoneId, state: switchState, timeout: timeout, intent: intent)
    }
    
    init(crownstoneId: UInt16, state: UInt8, timeout: UInt16, intent: UInt8) {
        self.timeout = timeout
        self.crownstoneId = crownstoneId
        self.state = state
        self.intent = intent
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr += Conversion.uint16_to_uint8_array(self.crownstoneId)
        arr.append(self.state)
        arr += Conversion.uint16_to_uint8_array(self.timeout)
        arr.append(self.intent)

        return arr
    }
}


class MeshSwitchPacket {
    var size : UInt8
    var packets : [StoneSwitchPacket]!
    
    init(packets: [StoneSwitchPacket]) {
        self.size = NSNumber(value: packets.count).uint8Value
        self.packets = packets
    }
    
    func getPacket() -> [UInt8] {
        var arr = [UInt8]()
        arr.append(self.size)
        for packet in self.packets {
            arr += packet.getPacket()
        }
        return arr
    }
}


class beaconConfigPacket {
    var major : UInt16 = 0
    var minor : UInt16 = 0
    var uuid  : [UInt8]!
    var txPower : Int8 = 0
    
    convenience init(uuid: String, major: UInt16, minor: UInt16, txPower: Int8) {
        let uintUUID : [UInt8] = Conversion.ibeaconUUIDString_to_uint8_array(uuid)
        self.init(uuid: uintUUID, major: major, minor: minor, txPower: txPower)
    }
    
    init(uuid: [UInt8], major: UInt16, minor: UInt16, txPower: Int8) {
        
    }
}


