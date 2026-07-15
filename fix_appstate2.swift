import Foundation

let url = URL(fileURLWithPath: "macos-menubar/Sources/macos-menubar/AppState.swift")
var content = try! String(contentsOf: url)

content = content.replacingOccurrences(of: "@Published var queue: [QueuedTrack] = []", with: """
    @Published var queue: [QueuedTrack] = []
    @Published var searchResults: [YTDLP.YTSearchResult] = []
""")

let replacement = """
    func addTrack(query: String) {
        status.searchStatus = "Searching YouTube / Local..."
        status.error = ""
        Task {
            do {
                let results = try await YTDLP.shared.search(query: query)
                await MainActor.run {
                    self.status.searchStatus = ""
                    self.searchResults = results
                }
            } catch {
                await MainActor.run {
                    self.status.searchStatus = ""
                    self.status.error = error.localizedDescription
                }
            }
        }
    }
    
    func enqueue(result: YTDLP.YTSearchResult) {
        status.searchStatus = "Loading stream..."
        status.error = ""
        searchResults = []
        
        Task {
            do {
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

content.replaceSubrange(startRange.lowerBound..<endRange.lowerBound, with: replacement + "\n    ")

try! content.write(to: url, atomically: true, encoding: .utf8)
