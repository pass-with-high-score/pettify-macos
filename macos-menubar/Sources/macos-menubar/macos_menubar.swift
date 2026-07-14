import Cocoa
import SwiftUI
import MediaPlayer

@main
struct MenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { SettingsView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let state = AppState()
    var floatingWindow: FloatingLyricsWindow!
    var settingsWindow: NSWindow?
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
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
        let showFloatingLyrics = UserDefaults.standard.bool(forKey: "showFloatingLyrics")
        if showFloatingLyrics || UserDefaults.standard.object(forKey: "showFloatingLyrics") == nil {
            floatingWindow.makeKeyAndOrderFront(nil)
            floatingWindow.snapToCorner()
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleFloatingLyrics"), object: nil, queue: .main) { [weak self] notification in
            let showVal = notification.object as? Bool
            DispatchQueue.main.async {
                if let show = showVal {
                    if show {
                        self?.floatingWindow.makeKeyAndOrderFront(nil)
                        self?.floatingWindow.snapToCorner()
                    } else {
                        self?.floatingWindow.orderOut(nil)
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenSettings"), object: nil, queue: .main) { [weak self] _ in
            self?.openSettings()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("QuitApp"), object: nil, queue: .main) { _ in
            NSApplication.shared.terminate(nil)
            exit(0)
        }
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
    
    @objc func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 650, height: 450),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false)
            window.center()
            window.setFrameAutosaveName("Settings")
            window.title = "Settings"
            window.contentView = NSHostingView(rootView: settingsView)
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
}
