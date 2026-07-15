import Foundation

// Script to update AppState.swift using Swift string replacement
let url = URL(fileURLWithPath: "macos-menubar/Sources/macos-menubar/AppState.swift")
var content = try! String(contentsOf: url)

// Remove timer initialization
content = content.replacingOccurrences(of: """
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.fetch()
            }
        }
        fetch()
""", with: """
        AudioPlayer.shared.$position.sink { [weak self] pos in
            self?.status.position = pos
            self?.updateNowPlaying()
            self?.updateCurrentLyric()
        }.store(in: &cancellables)
        
        AudioPlayer.shared.$duration.sink { [weak self] dur in
            self?.status.duration = dur
        }.store(in: &cancellables)
        
        AudioPlayer.shared.$percent.sink { [weak self] pct in
            self?.status.percent = pct
        }.store(in: &cancellables)
        
        AudioPlayer.shared.$paused.sink { [weak self] p in
            self?.status.paused = p
            self?.updateNowPlaying()
        }.store(in: &cancellables)
""")

// Add Combine import
content = content.replacingOccurrences(of: "import CoreImage", with: "import CoreImage\nimport Combine")

// Add cancellables set
content = content.replacingOccurrences(of: "var timer: Timer?", with: "var cancellables = Set<AnyCancellable>()")

// Replace networking methods
let startRange = content.range(of: "func fetch() {")!
let endRange = content.range(of: "func fetchLyrics(for title: String) {")!

let replacement = """
    func fetch() { }
    
    func post(_ endpoint: String) {
        if endpoint == "playpause" {
            AudioPlayer.shared.togglePlayPause()
        }
    }
    
    func seek(to pos: Double) {
        AudioPlayer.shared.seek(to: pos)
    }
    
    func setVolume(_ vol: Double) {
        status.volume = vol
        AudioPlayer.shared.volume = vol
    }
    
    func addTrack(query: String) {
        status.searchStatus = "Searching YouTube / Local..."
        status.error = ""
        Task {
            do {
                let result = try await YTDLP.shared.search(query: query)
                
                await MainActor.run {
                    self.status.title = result.title
                    self.status.artist = result.uploader
                    self.status.thumbnail = "https://i.ytimg.com/vi/\\(result.id)/hqdefault.jpg"
                    self.status.searchStatus = ""
                    
                    if self.status.title != self.lastSearchedTitle {
                        self.lastSearchedTitle = self.status.title
                        self.fetchLyrics(for: self.status.title)
                    }
                    if self.status.thumbnail != self.lastThumbnail {
                        self.lastThumbnail = self.status.thumbnail
                        self.extractDominantColor(from: self.status.thumbnail)
                    }
                }
                
                let streamURL = try await YTDLP.shared.getStreamURL(for: result.url)
                
                await MainActor.run {
                    AudioPlayer.shared.play(url: streamURL)
                }
            } catch {
                await MainActor.run {
                    self.status.searchStatus = ""
                    self.status.error = error.localizedDescription
                }
            }
        }
    }
    
    func quitBackend() {
        // No longer needed
    }
    
    """
content.replaceSubrange(startRange.lowerBound..<endRange.lowerBound, with: replacement)

try! content.write(to: url, atomically: true, encoding: .utf8)
