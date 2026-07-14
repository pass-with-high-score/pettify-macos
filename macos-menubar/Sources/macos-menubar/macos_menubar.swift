import Cocoa
import SwiftUI
import MediaPlayer

@main
struct MenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let state = AppState()
    var floatingWindow: FloatingLyricsWindow!
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = PopoverView(state: state)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Audio CLI")
            button.action = #selector(togglePopover(_:))
        }
        
        let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let floatingRect = NSRect(x: screenRect.minX, y: screenRect.minY, width: screenRect.width / 2, height: 500)
        let floatingContentView = FloatingLyricsView(state: state)
        floatingWindow = FloatingLyricsWindow(contentRect: floatingRect, backing: .buffered, defer: false)
        floatingWindow.state = state
        floatingWindow.contentView = NSHostingView(rootView: floatingContentView)
        floatingWindow.makeKeyAndOrderFront(nil)
        floatingWindow.snapToCorner() // Initialize position
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
