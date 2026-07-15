import Cocoa
import SwiftUI

class KaraokeWindow: NSWindow {
    var state: AppState?
    
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool, state: AppState) {
        self.state = state
        super.init(contentRect: contentRect, styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: backing, defer: flag)
        
        self.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        self.titlebarAppearsTransparent = true
        self.titleVisibility = .hidden
        self.isMovableByWindowBackground = true
        self.backgroundColor = .black
        
        let contentView = KaraokeView(state: state)
        self.contentView = NSHostingView(rootView: contentView)
        self.minSize = NSSize(width: 800, height: 600)
        
        // Dark appearance
        self.appearance = NSAppearance(named: .darkAqua)
    }
}
