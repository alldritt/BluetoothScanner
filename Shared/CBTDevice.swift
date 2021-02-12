//
//  CBTDevice.swift
//  CBScanner
//
//  Created by Mark Alldritt on 2020-03-02.
//  Copyright © 2020 Mark Alldritt. All rights reserved.
//

#if os(macOS)
import Cocoa

typealias RIColor = NSColor
typealias RIImage = NSImage
#else
import UIKit

typealias RIColor = UIColor
typealias RIImage = UIImage
#endif
import CoreBluetooth


class CBTDevice: NSObject, Identifiable, ObservableObject {
   
    enum State {
        case connected, connecting, disconnected, disconnecting
        
        var name: String {
            switch self {
            case .disconnected:
                return "Disconnected"
                
            case .disconnecting:
                return "Disconnecting"
                
            case .connected:
                return "Connected"
                
            case .connecting:
                return "Connecting"
            }
        }
        
        var color: RIColor {
            switch self {
            case .disconnected:
                return .gray
                
            case .disconnecting:
                return .orange
                
            case .connected:
                return .green
                
            case .connecting:
                return .orange
            }
        }
    }

    static let NameChangeNotification = Notification.Name("RIHub.nameChanged")
    static let StateChangeNotification = Notification.Name("RIHub.stateChanged")
    static let RSSIChangeNotification = Notification.Name("RIHub.rssiChanged")
    static let ServicesChangeNotification = Notification.Name("RIHub.servicesChanged")
    static let CharacteristicsChangeNotification = Notification.Name("RIHub.characteristicsChanged")
    static let IncludedServicesChangeNotification = Notification.Name("RIHub.includedServicesChanged")
    static let DescriptorsChangeNotification = Notification.Name("RIHub.DescriptorsChanged")

    static let ServiceKey = "service" // userData key for CharacteristicsChangeNotification and IncludedServicesChangeNotification
    static let CharacteristicKey = "characteristic" // userData key for DescriptorsChangeNotification

    static let DeviceLostInterval = TimeInterval(10)
    static let ConnectInterval = TimeInterval(10)
    static let RSSIReadInterval = TimeInterval(0.5)

    let centralManager: CBCentralManager
    let peripheral: CBPeripheral
    var lastSeen: Date
    var rssi: Int {
        didSet {
            if rssi != oldValue {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: Self.RSSIChangeNotification, object: self)
                }
            }
        }
    }
    
    var state: State {
        switch peripheral.state {
        case .connected:
            return .connected
            
        case .connecting:
            return .connecting
            
        case .disconnected:
            return .disconnected
            
        case .disconnecting:
            return .disconnecting
            
        @unknown default:
            fatalError()
        }
    }
    var deviceName: String {
        return peripheral.name ?? "unknown"
    }
    var image: RIImage? {
        return nil
    }
    var largeImage: RIImage? {
        return nil
    }
    var identifier: UUID {
        return peripheral.identifier
    }
    var services: [CBService] {
        return peripheral.services ?? []
    }
    var chacteristics: [CBService:[CBCharacteristic]] {
        return services.reduce([CBService:[CBCharacteristic]]()) { (result, service) -> [CBService:[CBCharacteristic]] in
            var result = result
            result[service] = service.characteristics ?? []
            return result
        }
    }
    var includedServices: [CBService:[CBService]] {
        return services.reduce([CBService:[CBService]]()) { (result, service) -> [CBService:[CBService]] in
            var result = result
            result[service] = service.includedServices ?? []
            return result
        }
    }

    private var lastState = State.disconnected
    private var lastName: String?
    private var connectDate = Date.distantPast
    private var rssiTimer: Timer?

    init(centralManager: CBCentralManager, peripheral: CBPeripheral, rssi: Int) {
        self.centralManager = centralManager
        self.peripheral = peripheral
        self.lastSeen = Date()
        self.rssi = rssi
        
        super.init()
        
        self.lastName = deviceName
        peripheral.delegate = self
    }
    
    deinit {
        disconnect()
    }
    
    func connect() {
        guard state == .disconnected || state == .disconnecting else { return }
        
        rssiTimer = Timer.scheduledTimer(withTimeInterval: Self.RSSIReadInterval,
                                         repeats: true,
                                         block: { [weak self] (_) in
                                            self?.peripheral.readRSSI()
        })
        
        let now = Date()
        
        lastSeen = now
        connectDate = now
        centralManager.connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnDisconnectionKey:1])
        broadcastStateChange()
    }

    func disconnect() {
        if rssiTimer != nil {
            rssiTimer?.invalidate()
            rssiTimer = nil
            lastSeen = Date()
            broadcastStateChange()
        }

        guard state == .connected || state == .connecting else { return }
        
        centralManager.cancelPeripheralConnection(peripheral)
    }
        
    func broadcastStateChange() {
        assert(Thread.isMainThread)
        
        if state != lastState {
            if state == .connected {
                //  Connection established, look for services...
                peripheral.discoverServices(nil /*[ Self.CGXServiceUUID, Self.MUSEServiceUUID] */)
            }
            lastState = state
            NotificationCenter.default.post(name: Self.StateChangeNotification, object: self)
        }
        if deviceName != lastName {
            lastName = deviceName
            NotificationCenter.default.post(name: Self.NameChangeNotification, object: self)
        }
    }
    
    func isLost(_ now: Date) -> Bool {
        if peripheral.state == .connecting && Date().timeIntervalSince(connectDate) >= Self.ConnectInterval { // timeout slow connections...
            disconnect()
        }
        
        //  Has this device been advertised lately?
        return peripheral.state == .disconnected && lastSeen.addingTimeInterval(Self.DeviceLostInterval) < now
    }
}


//  MARK: - CBPeripheralDelegate

extension CBTDevice: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        #if DEBUG
        print("didDiscoverServices: \(String(describing: peripheral.services))")
        #endif
        
        //  Let observers know we have services
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.ServicesChangeNotification, object: self)
        }

        //  Ask for the characteristics associated with each service the peripheral offers
        peripheral.services?.forEach { (service) in
            peripheral.discoverCharacteristics(nil, for: service)
        }
        //  Ask for the included services associated with each service the peripheral offers
        peripheral.services?.forEach { (service) in
            peripheral.discoverIncludedServices(nil, for: service)
        }
    }
        
    func peripheralDidUpdateName(_ peripheral: CBPeripheral) {
        #if DEBUG
        print("peripheralDidUpdateName: \(String(describing: peripheral.name))")
        #endif

        DispatchQueue.main.async {
            self.broadcastStateChange()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        #if DEBUG
        print("didReadRSSI: \(RSSI), error: \(String(describing: error))")
        #endif
        // TODO - deal with errors
        DispatchQueue.main.async {
            self.rssi = RSSI.intValue
        }
    }
        
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        #if DEBUG
        print("didDiscoverCharacteristicsFor: \(service), \(service.characteristics ?? []), error: \(String(describing: error))")
        #endif
        
        // TODO - deal with errors
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.CharacteristicsChangeNotification, object: self, userInfo: [Self.ServiceKey: service])
        }
        
        //  Ask for the descriptors associated with each chacteristic
        service.characteristics?.forEach { (characteristic) in
            peripheral.discoverDescriptors(for: characteristic)
        }

    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        #if DEBUG
        print("didDiscoverIncludedServicesFor: \(service), includedServices: \(service.includedServices ?? []), error: \(String(describing: error))")
        #endif

        // TODO - deal with errors
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.IncludedServicesChangeNotification, object: self, userInfo: [Self.ServiceKey: service])
        }
    }
        
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        #if DEBUG
        print("didDiscoverDescriptorsFor: \(characteristic), descriptors: \(characteristic.descriptors ?? []), error: \(String(describing: error))")
        #endif

        // TODO - deal with errors
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Self.DescriptorsChangeNotification, object: self, userInfo: [Self.ServiceKey: characteristic.service])
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        #if DEBUG
        print("didWriteValueFor: \(characteristic), error: \(String(describing: error))")
        #endif
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        #if DEBUG
        print("didUpdateValueFor: \(characteristic), error: \(String(describing: error))")
        #endif
    }
    
}

