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
        super.mouseDown(with: event)
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let initial = initialLocation else { return }
        let screenLocation = NSEvent.mouseLocation
        self.setFrameOrigin(NSPoint(x: screenLocation.x - initial.x, y: screenLocation.y - initial.y))
        
        let dx = event.deltaX
        let dy = event.deltaY
        DispatchQueue.main.async {
            withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.8)) {
                self.state?.dragVelocity = CGSize(width: dx, height: dy)
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        snapToCorner()
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                self.state?.dragVelocity = .zero
            }
        }
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
    @State private var isHovering = false
    @AppStorage("floatingOpacity") private var floatingOpacity = 1.0
    @AppStorage("floatingFontSize") private var floatingFontSize = 36.0

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
            if state.isMiniMode {
                songInfo
            } else {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        .padding(40)
        .opacity(floatingOpacity)
        .rotation3DEffect(.degrees(state.dragVelocity.width * 0.5), axis: (x: 0, y: 1, z: 0))
        .rotation3DEffect(.degrees(-state.dragVelocity.height * 0.5), axis: (x: 1, y: 0, z: 0))
        .offset(y: state.currentEasterEgg == .windowBounce ? -40 : 0)
        .animation(state.currentEasterEgg == .windowBounce ? .interpolatingSpring(stiffness: 100, damping: 0) : .spring(), value: state.currentEasterEgg)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: state.currentLyricIndex)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: state.isMiniMode)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        DispatchQueue.main.async {
                            state.addLocalTrack(url: url)
                        }
                    }
                }
            }
            return true
        }
    }
    
    @ViewBuilder
    var lyricsContent: some View {
        if !state.lyrics.isEmpty && state.currentLyricIndex >= 0 {
            VStack(alignment: state.isLeft ? .leading : .trailing, spacing: 10) {
                lyricLine(offset: -2)
                lyricLine(offset: -1)
                lyricLine(offset: 0)
                lyricLine(offset: 1)
                lyricLine(offset: 2)
            }
        }
    }
    
    @ViewBuilder
    func lyricLine(offset: Int) -> some View {
        let i = state.currentLyricIndex + offset
        if i >= 0 && i < state.lyrics.count {
            let distance = abs(offset)
            let baseSize = floatingFontSize
            let secondarySize = max(16.0, baseSize * 0.66)
            
            Text(state.lyrics[i].text)
                .font(.system(size: distance == 0 ? baseSize : secondarySize, weight: distance == 0 ? .black : .semibold, design: .rounded))
                .foregroundColor(.white)
                .opacity(distance == 0 ? 1.0 : (distance == 1 ? 0.4 : 0.1))
                .shadow(color: distance == 0 ? state.dominantColor.opacity(0.8) : .black.opacity(0.5), radius: distance == 0 ? 10 : 2, x: 0, y: distance == 0 ? 0 : 2)
                .blur(radius: distance == 0 ? 0 : CGFloat(distance) * 1.5)
                .multilineTextAlignment(state.isLeft ? .leading : .trailing)
                .lineLimit(distance == 0 ? 2 : 1)
                .id(state.lyrics[i].id)
                .transition(.opacity.combined(with: .move(edge: offset < 0 ? .top : .bottom)))
        }
    }
    
    @ViewBuilder
    var songInfo: some View {
        if state.status.title != "Loading..." {
            VStack(alignment: state.isLeft ? .leading : .trailing, spacing: 8) {
                HStack(spacing: 12) {
                    if !state.isLeft { infoText }
                    
                    if state.status.thumbnail != "" {
                        SpinningVinylView(state: state, imageURL: state.status.thumbnail)
                    } else {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    if state.isLeft { infoText }
                }
                
                HStack(spacing: 20) {
                    Button(action: { state.post("prev") }) {
                        Image(systemName: "backward.fill").font(.system(size: 14))
                    }.buttonStyle(.plain)
                    
                    Button(action: { state.post("playpause") }) {
                        Image(systemName: state.status.paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 18))
                    }.buttonStyle(.plain)
                    
                    Button(action: { state.post("next") }) {
                        Image(systemName: "forward.fill").font(.system(size: 14))
                    }.buttonStyle(.plain)
                    
                    Button(action: { 
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            state.isMiniMode.toggle()
                        }
                    }) {
                        Image(systemName: state.isMiniMode ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 14))
                    }.buttonStyle(.plain)
                }
                .foregroundColor(.white)
                .padding(.top, 4)
                .opacity(isHovering ? 1.0 : 0.3)
                .scaleEffect(isHovering ? 1.0 : 0.95)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
            }
            .padding(12)
            .background(
                ZStack {
                    VisualEffectView().cornerRadius(12).opacity(0.9)
                    FloatingNotesView(isPlaying: !state.status.paused, dominantColor: state.dominantColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .hueRotation(.degrees(state.currentEasterEgg == .raveMode ? 3600 : 0))
                .animation(state.currentEasterEgg == .raveMode ? .linear(duration: 2) : .default, value: state.currentEasterEgg)
            )
            .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
            .overlay(OnekoView(state: state))
            .onHover { hovering in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isHovering = hovering
                }
            }
        }
    }
    
    @ViewBuilder
    var infoText: some View {
        VStack(alignment: state.isLeft ? .leading : .trailing, spacing: 4) {
            MarqueeText(text: state.status.title, font: .system(size: 16, weight: .bold), containerWidth: 220, isLeft: state.isLeft)
                .foregroundColor(.white)
            
            if state.status.artist != "" {
                MarqueeText(text: state.status.artist, font: .system(size: 13), containerWidth: 220, isLeft: state.isLeft)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            HStack(spacing: 6) {
                if !state.isLeft {
                    AudioVisualizerView(isPlaying: !state.status.paused)
                        .padding(.trailing, 2)
                }
                
                Text(state.formatTime(state.status.position))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                
                CustomSlider(value: Binding(get: {
                    state.status.position
                }, set: { val in
                    state.status.position = val
                    state.seek(to: val)
                }), total: max(0.1, state.status.duration))
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

struct SpinningVinylView: View {
    @ObservedObject var state: AppState
    var imageURL: String
    
    @State private var rotation: Double = 0
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        AsyncImage(url: URL(string: imageURL)) { phase in
            if let image = phase.image {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.1)
                    Image(systemName: "music.note")
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.black.opacity(0.7), lineWidth: 4))
        .overlay(Circle().fill(Color.black.opacity(0.8)).frame(width: 12, height: 12))
        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
        .rotationEffect(.degrees(rotation))
        .onTapGesture {
            state.triggerRandomEasterEgg()
        }
        .onReceive(timer) { _ in
            if !state.status.paused {
                var speed = 2.0
                if state.currentEasterEgg == .hyperSpeed { speed = 50.0 }
                if state.currentEasterEgg == .reverseSpin { speed = -30.0 }
                if state.currentEasterEgg == .djScratch { speed = (Int.random(in: 0...1) == 0 ? 50.0 : -50.0) }
                rotation += speed
            }
        }
    }
}

struct MarqueeText: View {
    var text: String
    var font: Font
    var containerWidth: CGFloat
    var isLeft: Bool
    
    @State private var offset: CGFloat = 0
    @State private var textWidth: CGFloat = 0
    @State private var id = UUID()
    
    var body: some View {
        let isOversized = textWidth > containerWidth
        let align: Alignment = isOversized ? .leading : (isLeft ? .leading : .trailing)
        
        Text(text)
            .font(font)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear {
                        if textWidth != geo.size.width {
                            textWidth = geo.size.width
                            startAnimation()
                        }
                    }
                    .onChange(of: text) { _ in
                        offset = 0
                        textWidth = 0
                        id = UUID()
                    }
            })
            .offset(x: isOversized ? offset : 0)
            .frame(width: containerWidth, alignment: align)
            .clipped()
            .id(id)
    }
    
    func startAnimation() {
        if textWidth > containerWidth {
            let distance = textWidth - containerWidth + 20
            let duration = Double(distance) / 30.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.linear(duration: duration).delay(1.0).repeatForever(autoreverses: true)) {
                    self.offset = -distance
                }
            }
        }
    }
}
