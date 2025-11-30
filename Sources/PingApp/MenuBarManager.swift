import Cocoa
import SwiftUI

@MainActor
class MenuBarManager: NSObject {
    var statusItem: NSStatusItem
    var popover: NSPopover
    var appState: AppState
    
    override init() {
        appState = AppState()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        
        super.init()
        
        setupStatusItem()
        setupPopover()
    }
    
    private func setupStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "network", accessibilityDescription: "PingApp")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }
    
    private func setupPopover() {
        popover.contentSize = NSSize(width: 300, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView().environmentObject(appState))
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                // Activate app to bring it to front if needed, though for menu bar apps usually not needed for focus
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
