import Foundation

let url = URL(fileURLWithPath: "macos-menubar/Sources/macos-menubar/AppState.swift")
var content = try! String(contentsOf: url)

content = content.replacingOccurrences(of: "@Published var currentEasterEgg: EasterEgg? = nil", with: """
    @Published var currentEasterEgg: EasterEgg? = nil
    @Published var queue: [QueuedTrack] = []
""")

content = content.replacingOccurrences(of: "AudioPlayer.shared.$paused.sink", with: """
        AudioPlayer.shared.onFinish = { [weak self] in
            Task { @MainActor in
                self?.playNextInQueue()
            }
        }
        
        AudioPlayer.shared.$paused.sink
""")

let replacementFuncs = """
    func playNextInQueue() {
        if !queue.isEmpty {
            let next = queue.removeFirst()
            playQueuedTrack(next)
        } else {
            status.title = "No track playing"
            status.artist = ""
            status.thumbnail = ""
            AudioPlayer.shared.seek(to: 0)
            AudioPlayer.shared.togglePlayPause() // Pause
        }
    }
    
    func playQueuedTrack(_ track: QueuedTrack) {
        status.title = track.title
        status.artist = track.artist
        status.thumbnail = track.thumbnail
        
        if status.title != lastSearchedTitle {
            lastSearchedTitle = status.title
            fetchLyrics(for: status.title)
        }
        if status.thumbnail != lastThumbnail {
            lastThumbnail = status.thumbnail
            extractDominantColor(from: status.thumbnail)
        }
        
        AudioPlayer.shared.play(url: track.streamURL)
    }

    func post(_ endpoint: String) {
"""

content = content.replacingOccurrences(of: "func post(_ endpoint: String) {", with: replacementFuncs)

let addTrackCode = """
    func addTrack(query: String) {
        status.searchStatus = "Searching YouTube / Local..."
        status.error = ""
        Task {
            do {
                let result = try await YTDLP.shared.search(query: query)
                let streamURL = try await YTDLP.shared.getStreamURL(for: result.url)
                
                let qTrack = QueuedTrack(
                    title: result.title,
                    artist: result.uploader,
                    thumbnail: "https://i.ytimg.com/vi/\\(result.id)/hqdefault.jpg",
                    streamURL: streamURL
                )
                
                await MainActor.run {
                    self.status.searchStatus = ""
                    if self.status.title == "Loading..." || self.status.title == "No track playing" {
                        self.playQueuedTrack(qTrack)
                    } else {
                        self.queue.append(qTrack)
                    }
                }
            } catch {
                await MainActor.run {
                    self.status.searchStatus = ""
                    self.status.error = error.localizedDescription
                }
            }
        }
    }
"""

let startRange = content.range(of: "func addTrack(query: String) {")!
let endRange = content.range(of: "func quitBackend() {")!

content.replaceSubrange(startRange.lowerBound..<endRange.lowerBound, with: addTrackCode + "\n    ")

try! content.write(to: url, atomically: true, encoding: .utf8)
