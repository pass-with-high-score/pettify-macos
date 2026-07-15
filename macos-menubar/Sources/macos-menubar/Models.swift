import Cocoa
import SwiftUI
import MediaPlayer

enum RepeatMode {
    case off    // no repeat
    case one    // repeat current track
    case all    // repeat entire queue
}

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
    var searchStatus: String = ""
}

enum EQPreset: String, CaseIterable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case trebleBoost = "Treble Boost"
    case vocal = "Vocal"
    case rock = "Rock"
    case pop = "Pop"
    case jazz = "Jazz"
    case classical = "Classical"
    case electronic = "Electronic"
    case custom = "Custom"
    
    var gains: [Float] {
        switch self {
        case .flat: return [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        case .bassBoost: return [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]
        case .trebleBoost: return [0, 0, 0, 0, 0, 0, 2, 4, 5, 6]
        case .vocal: return [-2, -1, 0, 2, 4, 4, 2, 0, -1, -2]
        case .rock: return [5, 4, 3, 1, -1, -1, 1, 3, 4, 5]
        case .pop: return [-1, 2, 4, 5, 4, 2, 0, -1, -2, -2]
        case .jazz: return [3, 2, 1, 2, -1, -1, 0, 1, 2, 3]
        case .classical: return [4, 3, 2, 0, -2, -2, 0, 2, 3, 4]
        case .electronic: return [6, 5, 2, 0, -2, 0, 2, 4, 5, 6]
        case .custom: return [] // Handled separately
        }
    }
}
