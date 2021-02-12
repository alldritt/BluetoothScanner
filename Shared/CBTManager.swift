//
//  CBTManager.swift
//  CBScanner
//
//  Created by Mark Alldritt on 2020-03-17.
//  Copyright © 2020 Mark Alldritt. All rights reserved.
//

#if os(iOS)
import UIKit
#endif
import CoreBluetooth
//import ExternalAccessory


class CBTManager: NSObject {
    
    static let DevicesChangedNotification = Notification.Name("CBTManager.DevicesChangedNotification")
    static let BluetoothStateChangedNotification = Notification.Name("CBTManager.BluetoothStateChangedNotification")
    
    private (set) var isRunning = false
    private (set) var devicesByUUID: [UUID:CBTDevice] = [:] {
        didSet {
            if devicesByUUID != oldValue {
                NotificationCenter.default.post(name: Self.DevicesChangedNotification, object: self)
            }
        }
    }
    var uuids: [UUID] { // sorted by UUID
        return devicesByUUID.keys.sorted { (v1, v2) -> Bool in
            return v1.uuidString < v2.uuidString
        }
    }
    var devices: [CBTDevice] {
        return uuids.map { (uuid) in return self.devicesByUUID[uuid]! }
    }
    var state: CBManagerState {
        return centralManager?.state ?? .unknown
    }
    
    private let queue = DispatchQueue(label: "CBT")
    private var centralManager: CBCentralManager!
    private var timer: Timer?
    
    static let shared = CBTManager()
    
    override private init() {
        /*
        //  Ignore this, nothing to see here (LEGO Mindstorms stuff)
        NotificationCenter.default.addObserver(forName: NSNotification.Name.EAAccessoryDidConnect,
                                               object: nil,
                                               queue: nil) { (notification) in
            print("EAAccessoryDidConnect: \(notification)")
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.EAAccessoryDidDisconnect,
                                               object: nil,
                                               queue: nil) { (notification) in
            print("EAAccessoryDidDisconnect: \(notification)")
        }
 */
    }
    
    deinit {
        stop()
    }
    
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        devicesByUUID = devicesByUUID.filter({ (arg0) -> Bool in
            let (_, hub) = arg0
            
            return hub.state == .connected
        })

        if centralManager == nil {
            centralManager = CBCentralManager(delegate: self, queue: queue)
        }
        else {
            centralManagerDidUpdateState(centralManager)
        }
        
        //  Ignore this, nothing to see here (LEGO Mindstorms stuff)
        //EAAccessoryManager.shared().registerForLocalNotifications()
        //print("connectedAccessories: \(EAAccessoryManager.shared().connectedAccessories)")
    }
    
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        devicesByUUID = devicesByUUID.filter({ (arg0) -> Bool in
            let (_, hub) = arg0
            
            return hub.state == .connected
        })
        
        timer?.invalidate()
        timer = nil
        centralManager.stopScan()
        
        //  Ignore this, nothing to see here (LEGO Mindstorms stuff)
        //EAAccessoryManager.shared().unregisterForLocalNotifications()
    }
    
    private func timerFired(_ timer: Timer) {
        assert(Thread.isMainThread)
        
        let now = Date()
        self.devicesByUUID = self.devicesByUUID.filter({ (arg0) -> Bool in
            let (_, hub) = arg0
            
            return !hub.isLost(now)
        })
    }
}


extension CBTManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
            print("central.state is .unknown")
            break

        case .resetting:
            print("central.state is .resetting")
            break

        case .unsupported:
            print("central.state is .unsupported")
            break
        
        case .unauthorized:
            print("central.state is .unauthorized")
            break

        case .poweredOff:
            print("central.state is .poweredOff")
            if isRunning {
                print("  - no longer listening for devices")
                central.stopScan()
                DispatchQueue.main.async {
                    self.timer?.invalidate()
                    self.timer = nil
                    self.devices.forEach { (device) in
                        device.disconnect()
                    }
                    self.devicesByUUID.removeAll()
                }
            }
            break

        case .poweredOn:
            print("central.state is .poweredOn")
            if isRunning {
                print("  - listening for devices...")
                central.scanForPeripherals(withServices: nil,
                                           options: [CBCentralManagerScanOptionAllowDuplicatesKey:1])
                DispatchQueue.main.async {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: self.timerFired)
                }
            }
            break

        @unknown default:
            fatalError()
        }
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.BluetoothStateChangedNotification, object: self)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {                
        DispatchQueue.main.async {
            if let device = self.devicesByUUID[peripheral.identifier] {
                device.lastSeen = Date()
                device.rssi = RSSI.intValue
                device.broadcastStateChange()
            }
            else {
                print("didDiscover: \(peripheral), advertisementData: \(advertisementData), rssi: \(RSSI), when: \(Date())")
                
                self.devicesByUUID[peripheral.identifier] = CBTDevice(centralManager: self.centralManager, peripheral: peripheral, rssi: RSSI.intValue)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("didConnect: \(peripheral)")
        
        DispatchQueue.main.async {
            guard let device = self.devicesByUUID[peripheral.identifier] else { return }
            
            device.lastSeen = Date()
            device.broadcastStateChange()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("didFailToConnect: \(peripheral), error: \(String(describing: error))")

        DispatchQueue.main.async {
            guard let device = self.devicesByUUID[peripheral.identifier] else { return }
            
            device.lastSeen = Date()
            device.broadcastStateChange()
        }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("didDisconnectPeripheral: \(peripheral), error: \(String(describing: error))")

        DispatchQueue.main.async {
            guard let device = self.devicesByUUID[peripheral.identifier] else { return }
            
            device.disconnect()
            device.broadcastStateChange()
        }
    }
}
