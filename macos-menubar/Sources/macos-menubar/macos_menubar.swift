import Cocoa
import SwiftUI
import MediaPlayer

struct LyricLine: Identifiable {
    let id = UUID()
    let time: Double
    let text: String
}

struct TrackStatus: Decodable {
    var title: String
    var artist: String
    var thumbnail: String
    var paused: Bool
    var volume: Double
    var percent: Double
    var position: Double
    var duration: Double
}

@MainActor
class AppState: ObservableObject {
    @Published var status = TrackStatus(title: "Loading...", artist: "", thumbnail: "", paused: false, volume: 1.0, percent: 0, position: 0, duration: 0)
    @Published var lyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = -1
    @Published var isTop: Bool = false
    @Published var isLeft: Bool = true
    var lastSearchedTitle: String = ""
    var timer: Timer?
    
    init() {
        setupRemoteTransportControls()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetch()
        }
        fetch()
    }
    
    func fetch() {
        guard let url = URL(string: "http://localhost:13337/status") else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let s = try? JSONDecoder().decode(TrackStatus.self, from: data) {
                    self.status = s
                    self.updateNowPlaying()
                    self.updateCurrentLyric()
                    if s.title != self.lastSearchedTitle && s.title != "Loading..." {
                        self.lastSearchedTitle = s.title
                        self.fetchLyrics(for: s.title)
                    }
                }
            } catch {}
        }
    }
    
    func post(_ endpoint: String) {
        guard let url = URL(string: "http://localhost:13337/\(endpoint)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        Task {
            do {
                _ = try await URLSession.shared.data(for: req)
                try await Task.sleep(nanoseconds: 200_000_000)
                self.fetch()
            } catch {}
        }
    }
    
    func seek(to pos: Double) {
        guard let url = URL(string: "http://localhost:13337/seek?pos=\(pos)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        Task { _ = try? await URLSession.shared.data(for: req) }
    }
    
    func setVolume(_ vol: Double) {
        guard let url = URL(string: "http://localhost:13337/volume?vol=\(vol)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        Task { _ = try? await URLSession.shared.data(for: req) }
    }
    
    func fetchLyrics(for title: String) {
        let cleanTitle = title.components(separatedBy: "(")[0].components(separatedBy: "[")[0].trimmingCharacters(in: .whitespaces)
        guard let encoded = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = results.first,
                   let syncedLyrics = first["syncedLyrics"] as? String {
                    self.parseLRC(syncedLyrics)
                } else {
                    DispatchQueue.main.async { self.lyrics = [] }
                }
            } catch {
                DispatchQueue.main.async { self.lyrics = [] }
            }
        }
    }
    
    func parseLRC(_ lrc: String) {
        var lines: [LyricLine] = []
        let regex = try! NSRegularExpression(pattern: "\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\](.*)")
        for line in lrc.components(separatedBy: .newlines) {
            let nsString = line as NSString
            let results = regex.matches(in: line, range: NSRange(location: 0, length: nsString.length))
            if let match = results.first {
                let min = Double(nsString.substring(with: match.range(at: 1))) ?? 0
                let sec = Double(nsString.substring(with: match.range(at: 2))) ?? 0
                let msStr = nsString.substring(with: match.range(at: 3))
                let ms = Double(msStr) ?? 0
                let msDivider: Double = msStr.count == 3 ? 1000 : 100
                let text = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
                let time = min * 60 + sec + ms / msDivider
                lines.append(LyricLine(time: time, text: text))
            }
        }
        DispatchQueue.main.async { self.lyrics = lines }
    }
    
    func updateCurrentLyric() {
        let pos = status.position
        var bestIndex = -1
        for (i, line) in lyrics.enumerated() {
            if line.time <= pos + 0.3 { // small pre-fetch offset
                bestIndex = i
            } else {
                break
            }
        }
        if currentLyricIndex != bestIndex {
            DispatchQueue.main.async { self.currentLyricIndex = bestIndex }
        }
    }
    
    func updateNowPlaying() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = status.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = status.artist
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = status.position
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = status.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = status.paused ? 0.0 : 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        
        DispatchQueue.main.async {
            if let delegate = NSApp.delegate as? AppDelegate, let button = delegate.statusItem?.button {
                let iconName = self.status.paused ? "music.note" : "waveform"
                button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "Audio CLI")
            }
        }
    }
    
    func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite else { return "0:00" }
        let totalSeconds = Int(seconds)
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
    
    func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.addTarget { [unowned self] event in
            self.post("playpause")
            return .success
        }
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.post("playpause")
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            self.post("next")
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            self.post("prev")
            return .success
        }
    }
}

struct PopoverView: View {
    @ObservedObject var state: AppState
    
    var body: some View {
        VStack(spacing: 15) {
            if state.status.thumbnail != "" {
                AsyncImage(url: URL(string: state.status.thumbnail)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.black.opacity(0.2)
                    }
                }.frame(width: 220, height: 124).cornerRadius(12).shadow(radius: 5)
            } else {
                Color.black.opacity(0.2).frame(width: 220, height: 124).cornerRadius(12)
            }
            
            VStack(spacing: 5) {
                Text(state.status.title).font(.headline).lineLimit(1).frame(maxWidth: 220)
                    .help(state.status.title)
                if state.status.artist != "" {
                    Text(state.status.artist).font(.subheadline).foregroundColor(.secondary).lineLimit(1).frame(maxWidth: 220)
                        .help(state.status.artist)
                }
            }
            
            if !state.lyrics.isEmpty {
                VStack(spacing: 6) {
                    if state.currentLyricIndex >= 0 && state.currentLyricIndex < state.lyrics.count {
                        Text(state.lyrics[state.currentLyricIndex].text)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .id(state.lyrics[state.currentLyricIndex].id) // force transition
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Text("♪").font(.system(size: 15)).foregroundColor(.secondary)
                    }
                    
                    if state.currentLyricIndex + 1 < state.lyrics.count {
                        Text(state.lyrics[state.currentLyricIndex + 1].text)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                }
                .frame(height: 50)
                .animation(.easeInOut(duration: 0.3), value: state.currentLyricIndex)
            }
            
            HStack(spacing: 8) {
                Text(state.formatTime(state.status.position))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                    
                Slider(value: Binding(get: {
                    state.status.position
                }, set: { val in
                    state.status.position = val
                    state.seek(to: val)
                }), in: 0...max(0.1, state.status.duration))
                .controlSize(.small)
                .tint(.accentColor)
                
                Text(state.formatTime(state.status.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 30) {
                Button(action: { state.post("prev") }) { 
                    Image(systemName: "backward.fill").font(.title2) 
                }.buttonStyle(.plain)
                
                Button(action: { state.post("playpause") }) { 
                    Image(systemName: state.status.paused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 44)) 
                }.buttonStyle(.plain)
                
                Button(action: { state.post("next") }) { 
                    Image(systemName: "forward.fill").font(.title2) 
                }.buttonStyle(.plain)
            }
            
            HStack {
                Image(systemName: "speaker.fill").foregroundColor(.secondary).font(.caption2)
                Slider(value: Binding(get: {
                    state.status.volume
                }, set: { val in
                    state.status.volume = val
                    state.setVolume(val)
                }), in: 0...1)
                .controlSize(.mini)
                Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary).font(.caption2)
            }
        }
        .padding(20)
        .frame(width: 260, height: state.lyrics.isEmpty ? 350 : 450)
        .background(VisualEffectView().edgesIgnoringSafeArea(.all))
    }
}

struct AudioVisualizerView: View {
    var isPlaying: Bool
    @State private var heights: [CGFloat] = [0.2, 0.4, 0.6, 0.3]
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 3, height: isPlaying ? heights[i] * 12 : 3)
                    .animation(.easeInOut(duration: 0.15), value: heights[i])
            }
        }
        .frame(height: 12, alignment: .bottom)
        .onReceive(timer) { _ in
            if isPlaying {
                for i in 0..<4 {
                    heights[i] = CGFloat.random(in: 0.2...1.0)
                }
            }
        }
    }
}

struct OnekoView: View {
    @State private var catPos: CGPoint = CGPoint(x: -16, y: -16)
    @State private var direction: Direction = .right
    @State private var sleepTick = 50
    @State private var tickCounter = 0
    @State private var frameNo = 25
    @State private var surpriseTick = 0
    
    enum Direction { case right, down, left, up }
    
    let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let url = Bundle.module.url(forResource: "\(frameNo)", withExtension: "gif"),
                   let nsImage = NSImage(contentsOf: url) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .position(catPos)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
            .onReceive(timer) { _ in
                updateCat(size: geo.size)
            }
        }
        .allowsHitTesting(false)
    }
    
    func updateCat(size: CGSize) {
        tickCounter += 1
        
        if surpriseTick > 0 {
            surpriseTick -= 1
            frameNo = 32
            return
        }
        
        if sleepTick > 0 {
            sleepTick -= 1
            let slowTick = sleepTick / 4
            if sleepTick > 80 {
                frameNo = (slowTick % 2 == 0) ? 31 : 25 // lick
            } else if sleepTick > 40 {
                frameNo = (slowTick % 2 == 0) ? 27 : 28 // scratch
            } else if sleepTick > 30 {
                frameNo = 26 // yawn
            } else {
                frameNo = ((sleepTick / 8) % 2 == 0) ? 29 : 30 // sleep slowly
            }
            
            if sleepTick == 0 {
                surpriseTick = 4
            }
            return
        }
        
        let speed: CGFloat = 4
        
        switch direction {
        case .right:
            frameNo = (frameNo == 5) ? 6 : 5 // Right frames
            catPos.x += speed
            if catPos.x >= size.width + 16 {
                catPos.x = size.width + 16
                direction = .down
                maybeSleep()
            }
        case .down:
            frameNo = (frameNo == 9) ? 10 : 9 // Down frames
            catPos.y += speed
            if catPos.y >= size.height + 16 {
                catPos.y = size.height + 16
                direction = .left
                maybeSleep()
            }
        case .left:
            frameNo = (frameNo == 13) ? 14 : 13 // Left frames
            catPos.x -= speed
            if catPos.x <= -16 {
                catPos.x = -16
                direction = .up
                maybeSleep()
            }
        case .up:
            frameNo = (frameNo == 1) ? 2 : 1 // Up frames
            catPos.y -= speed
            if catPos.y <= -16 {
                catPos.y = -16
                direction = .right
                maybeSleep()
            }
        }
    }
    
    func maybeSleep() {
        if Int.random(in: 0...2) == 0 {
            sleepTick = 100
        }
    }
}

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
                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 0)
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
            .background(VisualEffectView().cornerRadius(12).opacity(0.9))
            .shadow(color: .black.opacity(0.5), radius: 5, x: 0, y: 2)
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
                
                ProgressView(value: state.status.position, total: max(0.1, state.status.duration))
                    .progressViewStyle(LinearProgressViewStyle(tint: .white))
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

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

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
