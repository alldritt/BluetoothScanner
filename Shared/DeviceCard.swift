//
//  DeviceCard.swift
//  Bluetooth Scanner
//
//  Created by Mark Alldritt on 2021-02-11.
//

import SwiftUI


//  Conditional modifier
//  Taken from: https://fivestars.blog/swiftui/conditional-modifiers.html
//
//  Not used at present...
extension View {
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}



struct UUIDView: View {
    @State var uuid: UUID
    
    var body: some View {
        Text(uuid.uuidString.uppercased())
    }
}

struct RSSISignalView: View {
    @State var rssi: Int
    
    private var rssiBars: Int {
        //  I'm grading the RSSI value (roughly) based on this page: https://www.metageek.com/training/resources/understanding-rssi.html
        
        switch rssi {
        case (-40)...0:
            return 5
            
        case (-67)...(-41):
            return 4
            
        case (-70)...(-68):
            return 3
            
        case (-80)...(-71):
            return 2
            
        case (-90)...(-81):
            return 1
            
        default:
            return 0
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Text("NNNN").hidden().overlay(SignalStrengthIndicator(bars: rssiBars, totalBars: 5))
            Text("\(rssi) dB")
        }
    }
}

struct DeviceCard: View {
    @State var update = false
    @ObservedObject var device: CBTDevice;

    var isMacOS: Bool {
        if #available(macOS 10.0, *) {
            return true
        }
        else {
            return false
        }
    }

    var body: some View {
        //Button(action: { // TODO - Presence of button breaks appearance on MacOS
        //    print("pressed!") // TODO - at some point there will be a detail view
        //}) {
            VStack(alignment: .leading) {
                let _ = update
                
                HStack(alignment: .center, spacing: 0) {
                    Image("Speaker") // TODO - detect device type and show an appropriate image...
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 70, alignment: .leading)
                        .padding(EdgeInsets(top: 0, leading: 5, bottom: 0, trailing: 5))
                    VStack(alignment: .leading) {
                        Text(device.deviceName)
                            .font(.headline)
                            .foregroundColor(.white)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        UUIDView(uuid: device.identifier)
                            .font(.footnote)
                            .foregroundColor(Color(white: 0.9))
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        RSSISignalView(rssi: device.rssi)
                            .font(.footnote)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(0)
                }
            }
            .frame(minWidth: 300, idealWidth: 300, maxWidth: .infinity, minHeight: 80, idealHeight: 80, maxHeight: 80)
            .background(Color(white: 0.2))
            .cornerRadius(8)
            .onReceive(NotificationCenter.default
                        .publisher(for: CBTDevice.NameChangeNotification, object: device)) { _ in
                self.update.toggle()
            }
            .onReceive(NotificationCenter.default
                        .publisher(for: CBTDevice.StateChangeNotification, object: device)) { _ in
                self.update.toggle()
            }
            .onReceive(NotificationCenter.default
                        .publisher(for: CBTDevice.RSSIChangeNotification, object: device)) { _ in
                self.update.toggle()
            }
        //}
    }
}

