//
//  BluetoothScannerApp.swift
//  Shared
//
//  Created by Mark Alldritt on 2021-02-11.
//

#if os(macOS)
import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        CBTManager.shared.start() // start listening for Bluetooth devices...

        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView()

        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Bluetooth Scanner"
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Main Window222")
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

#else
import SwiftUI

@main
struct BluetoothScannerApp: App {
    
    init() {
        CBTManager.shared.start()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#endif



