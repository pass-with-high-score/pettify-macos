import Foundation

let url = URL(fileURLWithPath: "macos-menubar/Sources/macos-menubar/AppState.swift")
var content = try! String(contentsOf: url)

content = content.replacingOccurrences(of: """
    func post(_ endpoint: String) {
        if endpoint == "playpause" {
            AudioPlayer.shared.togglePlayPause()
        }
    }
""", with: """
    func post(_ endpoint: String) {
        if endpoint == "playpause" {
            AudioPlayer.shared.togglePlayPause()
        } else if endpoint == "next" {
            playNextInQueue()
        }
    }
""")

try! content.write(to: url, atomically: true, encoding: .utf8)
