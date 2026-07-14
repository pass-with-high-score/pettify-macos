import Cocoa
import SwiftUI
import MediaPlayer
import CoreImage

enum EasterEgg {
    case hyperSpeed
    case reverseSpin
    case raveMode
    case djScratch
    case windowBounce
}

@MainActor
class AppState: ObservableObject {
    @Published var status = TrackStatus(title: "No track", artist: "", thumbnail: "", paused: true, volume: 1.0, percent: 0, position: 0, duration: 0)
    @Published var lyrics: [LyricLine] = []
    @Published var currentLyricIndex: Int = -1
    @Published var isTop: Bool = false
    @Published var isLeft: Bool = true
    @Published var dominantColor: Color = .white
    @Published var dragVelocity: CGSize = .zero
    @Published var isMiniMode: Bool = false
    @Published var currentEasterEgg: EasterEgg? = nil
    
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off

    let ytdlp = YtDlpService()
    @Published var audioPlayer = AudioPlayerService()
    var tracks: [TrackInfo] = []
    var currentTrackIndex: Int = -1

    var lastSearchedTitle: String = ""
    var lastThumbnail: String = ""
    var timer: Timer?

    init() {
        let defaultVol = UserDefaults.standard.object(forKey: "defaultVolume") as? Double ?? 1.0
        status.volume = defaultVol
        audioPlayer.setVolume(Float(defaultVol))
        
        setupRemoteTransportControls()
        
        // Auto-cleanup cache on startup
        performCacheCleanup()

        audioPlayer.onTrackFinished = { [weak self] in
            Task { @MainActor in
                self?.playNext()
            }
        }

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFromPlayer()
            }
        }

        // Auto-download yt-dlp binary on first launch
        Task {
            await ytdlp.ensureBinary()
        }
    }

    // MARK: - Player State Sync

    private func updateFromPlayer() {
        status.position = audioPlayer.currentTime
        status.duration = audioPlayer.duration
        status.paused = !audioPlayer.isPlaying
        status.volume = Double(audioPlayer.volume)

        if status.duration > 0 {
            status.percent = (status.position / status.duration) * 100.0
        } else {
            status.percent = 0
        }

        updateCurrentLyric()
        updateNowPlaying()
    }

    private func updateStatus() {
        status.position = audioPlayer.currentTime
        status.duration = audioPlayer.duration
        status.paused = !audioPlayer.isPlaying
        status.volume = Double(audioPlayer.volume)

        if status.duration > 0 {
            status.percent = (status.position / status.duration) * 100.0
        } else {
            status.percent = 0
        }
    }

    // MARK: - Controls (post() kept for view compatibility)

    func post(_ endpoint: String) {
        switch endpoint {
        case "playpause":
            audioPlayer.togglePlayPause()
            updateStatus()
        case "next":
            playNext()
        case "prev":
            playPrev()
        case "shuffle":
            toggleShuffle()
        case "repeat":
            cycleRepeatMode()
        default:
            break
        }
    }

    func seek(to pos: Double) {
        audioPlayer.seek(to: pos)
        status.position = pos
    }

    func setVolume(_ vol: Double) {
        audioPlayer.setVolume(Float(vol))
        status.volume = vol
    }

    // MARK: - Track Management
    
    func toggleShuffle() {
        isShuffled.toggle()
    }
    
    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .one
        case .one: repeatMode = .all
        case .all: repeatMode = .off
        }
    }
    
    func removeTrack(at index: Int) {
        guard index >= 0 && index < tracks.count else { return }
        tracks.remove(at: index)
        if index == currentTrackIndex {
            if tracks.isEmpty {
                currentTrackIndex = -1
                audioPlayer.stop()
                status.title = "No track"
                status.artist = ""
                status.thumbnail = ""
                status.paused = true
            } else {
                currentTrackIndex = min(currentTrackIndex, tracks.count - 1)
                Task { await playCurrentTrack() }
            }
        } else if index < currentTrackIndex {
            currentTrackIndex -= 1
        }
    }

    func addTrack(query: String) {
        status.searchStatus = "Searching..."
        Task {
            do {
                let trackInfo = try await ytdlp.search(query: query)
                tracks.append(trackInfo)
                status.searchStatus = "Downloading audio..."
                let _ = try await ytdlp.downloadAudio(from: trackInfo.url)
                status.searchStatus = ""
                // If nothing playing, play immediately
                if currentTrackIndex < 0 || !audioPlayer.isPlaying {
                    currentTrackIndex = tracks.count - 1
                    await playCurrentTrack()
                }
            } catch {
                status.searchStatus = "Error: \(error.localizedDescription)"
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                status.searchStatus = ""
            }
        }
    }
    
    func addLocalTrack(url: URL) {
        let asset = AVAsset(url: url)
        var title = url.deletingPathExtension().lastPathComponent
        var artist = "Local File"
        var artworkUrl: String? = nil
        
        Task {
            if let metadata = try? await asset.load(.metadata) {
                for item in metadata {
                    if let commonKey = item.commonKey?.rawValue {
                        switch commonKey {
                        case "title":
                            if let val = try? await item.load(.stringValue) { title = val }
                        case "artist":
                            if let val = try? await item.load(.stringValue) { artist = val }
                        case "artwork":
                            if let data = try? await item.load(.dataValue) {
                                let tempDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("audio-cli-yt/artworks")
                                try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                                let artworkFile = tempDir.appendingPathComponent(UUID().uuidString + ".jpg")
                                try? data.write(to: artworkFile)
                                artworkUrl = artworkFile.absoluteString
                            }
                        default:
                            break
                        }
                    }
                }
            }
            
            if artist == "Local File" {
                let parts = title.components(separatedBy: "-")
                if parts.count >= 2 {
                    artist = parts[0].trimmingCharacters(in: .whitespaces)
                    title = parts[1...].joined(separator: "-").trimmingCharacters(in: .whitespaces)
                }
            }
            
            if artworkUrl == nil {
                // Try fetching artwork from iTunes
                let term = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "https://itunes.apple.com/search?term=\(term)&media=music&entity=song&limit=1"),
                   let (data, _) = try? await URLSession.shared.data(from: url),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let first = results.first,
                   let artUrl = first["artworkUrl100"] as? String {
                    artworkUrl = artUrl.replacingOccurrences(of: "100x100bb", with: "600x600bb")
                }
            }
            
            let trackInfo = TrackInfo(title: title, videoId: "", url: url.absoluteString, artist: artist, localThumbnailURL: artworkUrl)
            
            await MainActor.run {
                tracks.append(trackInfo)
                if tracks.count == 1 {
                    currentTrackIndex = 0
                    Task { await playCurrentTrack() }
                }
            }
        }
    }

    func playCurrentTrack() async {
        guard currentTrackIndex >= 0 && currentTrackIndex < tracks.count else { return }
        let track = tracks[currentTrackIndex]

        status.title = track.title
        status.artist = track.artist
        status.thumbnail = track.thumbnailURL
        status.position = 0
        status.duration = 0
        status.percent = 0

        // Fetch lyrics for new track
        if track.title != lastSearchedTitle {
            lastSearchedTitle = track.title
            fetchLyrics(for: track.title, artist: track.artist)
        }

        // Extract dominant color from thumbnail
        if track.thumbnailURL != lastThumbnail && !track.thumbnailURL.isEmpty {
            lastThumbnail = track.thumbnailURL
            extractDominantColor(from: track.thumbnailURL)
        }

        do {
            let localPath: URL
            if track.url.hasPrefix("file://") {
                // Local file playback
                localPath = URL(string: track.url)!
                status.searchStatus = ""
            } else {
                // Auto-cleanup cache before downloading
                performCacheCleanup()
                
                // Download audio if not already cached
                let audioQuality = UserDefaults.standard.string(forKey: "audioQuality") ?? "bestaudio"
                localPath = try await ytdlp.downloadAudio(from: track.url, quality: audioQuality)
            }
            audioPlayer.play(fileURL: localPath)
            updateStatus()
        } catch {
            status.searchStatus = "Playback error: \(error.localizedDescription)"
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            status.searchStatus = ""
        }
    }

    func playNext() {
        guard !tracks.isEmpty else { return }
        if repeatMode == .one {
            Task { await playCurrentTrack() }
            return
        }
        if isShuffled {
            var nextIndex = Int.random(in: 0..<tracks.count)
            if tracks.count > 1 {
                while nextIndex == currentTrackIndex {
                    nextIndex = Int.random(in: 0..<tracks.count)
                }
            }
            currentTrackIndex = nextIndex
        } else {
            currentTrackIndex += 1
            if currentTrackIndex >= tracks.count {
                if repeatMode == .all {
                    currentTrackIndex = 0
                } else {
                    currentTrackIndex = tracks.count - 1
                    audioPlayer.stop()
                    status.paused = true
                    return
                }
            }
        }
        Task { await playCurrentTrack() }
    }

    func playPrev() {
        guard !tracks.isEmpty else { return }
        if repeatMode == .one {
            Task { await playCurrentTrack() }
            return
        }
        if isShuffled {
            var prevIndex = Int.random(in: 0..<tracks.count)
            if tracks.count > 1 {
                while prevIndex == currentTrackIndex {
                    prevIndex = Int.random(in: 0..<tracks.count)
                }
            }
            currentTrackIndex = prevIndex
        } else {
            currentTrackIndex -= 1
            if currentTrackIndex < 0 {
                if repeatMode == .all {
                    currentTrackIndex = tracks.count - 1
                } else {
                    currentTrackIndex = 0
                }
            }
        }
        Task { await playCurrentTrack() }
    }
    
    private func performCacheCleanup() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("audio-cli-yt")
        let maxCacheSizeGB = UserDefaults.standard.object(forKey: "maxCacheSizeGB") as? Double ?? 2.0
        let maxBytes = Int64(maxCacheSizeGB * 1024 * 1024 * 1024)
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey]) else { return }
        
        var fileStats: [(url: URL, size: Int64, date: Date)] = []
        var totalSize: Int64 = 0
        
        for file in files {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64,
               let date = attrs[.creationDate] as? Date {
                fileStats.append((url: file, size: size, date: date))
                totalSize += size
            }
        }
        
        if totalSize > maxBytes {
            // Sort by oldest first
            fileStats.sort { $0.date < $1.date }
            
            for file in fileStats {
                try? FileManager.default.removeItem(at: file.url)
                totalSize -= file.size
                if totalSize <= maxBytes {
                    break
                }
            }
        }
    }

    // MARK: - Lyrics

    func fetchLyrics(for title: String, artist: String = "") {
        var query = title.components(separatedBy: "(")[0].components(separatedBy: "[")[0].components(separatedBy: "|")[0].components(separatedBy: "｜")[0].trimmingCharacters(in: .whitespaces)
        if !artist.isEmpty && artist != "Local File" && !query.lowercased().contains(artist.lowercased()) {
            query += " " + artist
        }
        
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://lrclib.net/api/search?q=\(encoded)") else { return }

        var request = URLRequest(url: url)
        request.setValue("AudioCLI/1.0 (https://github.com/nqmgaming/audio-cli)", forHTTPHeaderField: "User-Agent")

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: request)
                if let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                   let first = results.first {
                    print("Found LRC result: \(first["trackName"] ?? "")")
                    if let syncedLyrics = first["syncedLyrics"] as? String {
                        self.parseLRC(syncedLyrics)
                    } else {
                        print("No synced lyrics found")
                        DispatchQueue.main.async { self.lyrics = [] }
                    }
                } else {
                    print("No results from lrclib")
                    DispatchQueue.main.async { self.lyrics = [] }
                }
            } catch {
                print("LRC Error: \(error)")
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
        print("Parsed \(lines.count) lyrics lines")
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

    // MARK: - Now Playing & Remote Controls

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
            self.audioPlayer.togglePlayPause()
            self.updateStatus()
            return .success
        }
        commandCenter.pauseCommand.addTarget { [unowned self] event in
            self.audioPlayer.togglePlayPause()
            self.updateStatus()
            return .success
        }
        commandCenter.nextTrackCommand.addTarget { [unowned self] event in
            self.playNext()
            return .success
        }
        commandCenter.previousTrackCommand.addTarget { [unowned self] event in
            self.playPrev()
            return .success
        }
    }

    // MARK: - Visual

    func extractDominantColor(from imageURL: String) {
        guard let url = URL(string: imageURL) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let nsImage = NSImage(data: data),
                      let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

                let ciImage = CIImage(cgImage: cgImage)
                let extentVector = CIVector(x: ciImage.extent.origin.x, y: ciImage.extent.origin.y, z: ciImage.extent.size.width, w: ciImage.extent.size.height)

                guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
                      let outputImage = filter.outputImage else { return }

                var bitmap = [UInt8](repeating: 0, count: 4)
                let context = CIContext(options: [.workingColorSpace: kCFNull!])
                context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

                let color = Color(red: Double(bitmap[0]) / 255.0, green: Double(bitmap[1]) / 255.0, blue: Double(bitmap[2]) / 255.0)
                DispatchQueue.main.async {
                    self.dominantColor = color
                }
            } catch {}
        }
    }

    // MARK: - Easter Eggs

    func triggerRandomEasterEgg() {
        guard self.currentEasterEgg == nil else { return }
        let actions: [EasterEgg] = [.hyperSpeed, .reverseSpin, .raveMode, .djScratch, .windowBounce]
        self.currentEasterEgg = actions.randomElement()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring()) {
                self.currentEasterEgg = nil
            }
        }
    }
}
