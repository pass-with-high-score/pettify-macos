import Cocoa
import SwiftUI
import MediaPlayer

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
