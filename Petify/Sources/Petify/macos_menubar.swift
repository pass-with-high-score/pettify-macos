import Cocoa
import SwiftUI
import MediaPlayer

@main
struct MenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { SettingsView(state: appDelegate.state) }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let state = AppState()
    var floatingWindow: FloatingLyricsWindow!
    var nekoWindow: NSWindow?
    var settingsWindow: NSWindow?
    var karaokeWindow: KaraokeWindow?
    var wasPlayingBeforeSleep = false
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        if showDockIcon {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        
        // Set app icon
        if let icon = Bundle.module.image(forResource: "AppIcon") {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = PopoverView(state: state)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 450)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Petify")
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
        
        // Setup neko screen-edge window
        setupNekoScreenEdge()
        
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
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenKaraoke"), object: nil, queue: .main) { [weak self] _ in
            self?.openKaraoke()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("CloseKaraoke"), object: nil, queue: .main) { [weak self] _ in
            self?.karaokeWindow?.close()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("QuitApp"), object: nil, queue: .main) { _ in
            NSApplication.shared.terminate(nil)
            exit(0)
        }
        
        // Smart Auto-Pause
        let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter
        workspaceNotificationCenter.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if !self.state.status.paused {
                    self.wasPlayingBeforeSleep = true
                    self.state.post("playpause")
                } else {
                    self.wasPlayingBeforeSleep = false
                }
            }
        }
        
        workspaceNotificationCenter.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: nil) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.wasPlayingBeforeSleep {
                    self.state.post("playpause")
                    self.wasPlayingBeforeSleep = false
                }
            }
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
            let settingsView = SettingsView(state: state)
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
    
    @objc func openKaraoke() {
        if karaokeWindow == nil {
            let screenRect = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width: CGFloat = min(1000, screenRect.width * 0.8)
            let height: CGFloat = min(700, screenRect.height * 0.8)
            let rect = NSRect(x: screenRect.midX - width/2, y: screenRect.midY - height/2, width: width, height: height)
            
            karaokeWindow = KaraokeWindow(contentRect: rect, backing: .buffered, defer: false, state: state)
            karaokeWindow?.isReleasedWhenClosed = false
        }
        
        // Close popover when opening karaoke
        if popover.isShown {
            popover.performClose(nil)
        }
        
        NSApp.activate(ignoringOtherApps: true)
        karaokeWindow?.makeKeyAndOrderFront(nil)
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(self)
    }
    
    func setupNekoScreenEdge() {
        let isScreenEdge = UserDefaults.standard.bool(forKey: "nekoScreenEdge")
        if isScreenEdge {
            showNekoScreenWindow()
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ToggleNekoMode"), object: nil, queue: .main) { [weak self] notification in
            guard let self = self else { return }
            let screenEdge = notification.object as? Bool ?? false
            Task { @MainActor in
                if screenEdge {
                    self.showNekoScreenWindow()
                } else {
                    self.nekoWindow?.orderOut(nil)
                    self.nekoWindow = nil
                }
            }
        }
    }
    
    func showNekoScreenWindow() {
        if nekoWindow != nil { return }
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        
        let nekoView = OnekoView(state: state)
        window.contentView = NSHostingView(rootView: nekoView)
        window.makeKeyAndOrderFront(nil)
        nekoWindow = window
    }
}
