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
