//
//  ContentView.swift
//  Shared
//
//  Created by Mark Alldritt on 2021-02-11.
//

import SwiftUI


struct DeviceListView: View {
    @State var devices: [CBTDevice] = CBTManager.shared.devices
    
    let devicesPublisher = NotificationCenter.default
        .publisher(for: CBTManager.DevicesChangedNotification)
    let namesPublisher = NotificationCenter.default
        .publisher(for: CBTDevice.NameChangeNotification)

    var body: some View {
        List(devices) { (device) in
            DeviceCard(device: device)
        }
        .onReceive(devicesPublisher) { (output) in
            updateDevices()
        }
        .onReceive(namesPublisher) { (output) in
            updateDevices()
        }
    }
    
    private func updateDevices() {
        #if false
        //  Only list devices with names...
        let visibeDevices = CBTManager.shared.devices.filter { (device) in
            return device.deviceName != "unknown"
        }
        #else
        //  List all devices...
        let visibeDevices = CBTManager.shared.devices
        #endif
        
        if self.devices != visibeDevices {
            self.devices = visibeDevices
        }
    }
}


struct ContentView: View {
    @State var update = false
    
    let btPublisher = NotificationCenter.default
        .publisher(for: CBTManager.BluetoothStateChangedNotification)

    var body: some View {
        let _ = update
        
        Group {
            switch CBTManager.shared.state {
            case .unknown:
                Text("Unknown Bluetooth State")
            
            case .resetting:
                Text("Bluetooth Resetting...")
                
            case .unsupported:
                Text("Bluetooth Unsupported")
                
            case .unauthorized:
                Text("Bluetooth Unauthorized")

            case .poweredOff:
                Text("Bluetooth Powered Off")

            case .poweredOn:
                DeviceListView()
                
            @unknown default:
                Text("Unknown Bluetooth State")
            }
        }
        .onReceive(btPublisher) { (output) in
            self.update.toggle()
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
