import Cocoa
import SwiftUI
import MediaPlayer

class FloatingLyricsWindow: NSWindow {
    var state: AppState?
    var initialLocation: NSPoint?
    
    init(contentRect: NSRect, backing: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: .borderless, backing: backing, defer: flag)
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect // Allow free dragging off-screen
    }
    
    override func mouseDown(with event: NSEvent) {
        self.initialLocation = event.locationInWindow
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let initial = initialLocation else { return }
        let screenLocation = NSEvent.mouseLocation
        self.setFrameOrigin(NSPoint(x: screenLocation.x - initial.x, y: screenLocation.y - initial.y))
    }
    
    override func mouseUp(with event: NSEvent) {
        snapToCorner()
    }
    
    func snapToCorner() {
        guard let screen = self.screen else { return }
        let screenRect = screen.visibleFrame
        let windowRect = self.frame
        let padding: CGFloat = 60
        
        let midX = windowRect.midX
        let midY = windowRect.midY
        
        let isLeft = midX < screenRect.midX
        let isTop = midY > screenRect.midY
        
        let targetX: CGFloat = isLeft ? screenRect.minX + padding : screenRect.maxX - windowRect.width - padding
        let targetY: CGFloat = isTop ? screenRect.maxY - windowRect.height - padding : screenRect.minY + padding
        
        DispatchQueue.main.async {
            self.state?.isTop = isTop
            self.state?.isLeft = isLeft
        }
        
        let targetFrame = NSRect(x: targetX, y: targetY, width: windowRect.width, height: windowRect.height)
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.4
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().setFrame(targetFrame, display: true)
        }, completionHandler: nil)
    }
}

struct FloatingLyricsView: View {
    @ObservedObject var state: AppState

    var alignment: Alignment {
        switch (state.isTop, state.isLeft) {
        case (true, true): return .topLeading
        case (true, false): return .topTrailing
        case (false, true): return .bottomLeading
        case (false, false): return .bottomTrailing
        }
    }

    var body: some View {
        VStack(alignment: state.isLeft ? .leading : .trailing, spacing: 12) {
            if state.isTop {
                songInfo
                Spacer().frame(height: 10)
                lyricsContent
            } else {
                lyricsContent
                Spacer().frame(height: 10)
                songInfo
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .padding(40)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.currentLyricIndex)
        .animation(.easeInOut(duration: 0.4), value: state.isTop)
        .animation(.easeInOut(duration: 0.4), value: state.isLeft)
    }
    
    @ViewBuilder
    var lyricsContent: some View {
        if !state.lyrics.isEmpty && state.currentLyricIndex >= 0 {
            if state.currentLyricIndex - 1 >= 0 {
                Text(state.lyrics[state.currentLyricIndex - 1].text)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 2)
                    .multilineTextAlignment(state.isLeft ? .leading : .trailing)
                    .lineLimit(1)
            }
            
            if state.currentLyricIndex < state.lyrics.count {
                Text(state.lyrics[state.currentLyricIndex].text)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: state.dominantColor.opacity(0.8), radius: 10, x: 0, y: 0)
                    .multilineTextAlignment(state.isLeft ? .leading : .trailing)
                    .lineLimit(2)
                    .id(state.lyrics[state.currentLyricIndex].id)
                    .transition(.opacity.combined(with: .move(edge: state.isTop ? .top : .bottom)))
            }
            
            if state.currentLyricIndex + 1 < state.lyrics.count {
                Text(state.lyrics[state.currentLyricIndex + 1].text)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 2)
                    .multilineTextAlignment(state.isLeft ? .leading : .trailing)
                    .lineLimit(1)
            }
        }
    }
    
    @ViewBuilder
    var songInfo: some View {
        if state.status.title != "Loading..." {
            HStack(spacing: 12) {
                if !state.isLeft { infoText }
                
                if state.status.thumbnail != "" {
                    AsyncImage(url: URL(string: state.status.thumbnail)) { phase in
                        if let image = phase.image {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color.white.opacity(0.1)
                                Image(systemName: "music.note")
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }.frame(width: 40, height: 40).cornerRadius(6)
                } else {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                }
                
                if state.isLeft { infoText }
            }
            .padding(12)
            .background(
                ZStack {
                    VisualEffectView().cornerRadius(12).opacity(0.9)
                    FloatingNotesView(isPlaying: !state.status.paused, dominantColor: state.dominantColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            .overlay(OnekoView())
        }
    }
    
    @ViewBuilder
    var infoText: some View {
        VStack(alignment: state.isLeft ? .leading : .trailing, spacing: 4) {
            Text(state.status.title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
            
            if state.status.artist != "" {
                Text(state.status.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            HStack(spacing: 6) {
                if !state.isLeft {
                    AudioVisualizerView(isPlaying: !state.status.paused)
                        .padding(.trailing, 2)
                }
                
                Text(state.formatTime(state.status.position))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                CustomProgressBar(value: state.status.position, total: max(0.1, state.status.duration))
                    .frame(width: 120)
                
                Text(state.formatTime(state.status.duration))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                if state.isLeft {
                    AudioVisualizerView(isPlaying: !state.status.paused)
                        .padding(.leading, 2)
                }
            }
            .padding(.top, 2)
        }
    }
}
