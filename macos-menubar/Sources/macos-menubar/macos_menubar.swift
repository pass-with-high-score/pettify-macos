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
    var lastSearchedTitle: String = ""
    
    init() {
        setupRemoteTransportControls()
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
    @StateObject var state = AppState()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
            
            Slider(value: Binding(get: {
                state.status.position
            }, set: { val in
                state.status.position = val
                state.seek(to: val)
            }), in: 0...max(0.1, state.status.duration))
            .controlSize(.small)
            .tint(.accentColor)
            
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
        .frame(width: 260, height: state.lyrics.isEmpty ? 320 : 380)
        .background(VisualEffectView().edgesIgnoringSafeArea(.all))
        .onReceive(timer) { _ in state.fetch() }
        .onAppear { state.fetch() }
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
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = PopoverView()
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Audio CLI")
            button.action = #selector(togglePopover(_:))
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
}
