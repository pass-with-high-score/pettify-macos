import Foundation

let url = URL(fileURLWithPath: "macos-menubar/Sources/macos-menubar/AudioPlayer.swift")
var content = try! String(contentsOf: url)
content = content.replacingOccurrences(of: """
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            Task { @MainActor [weak self] in
""", with: """
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
""")
content = content.replacingOccurrences(of: """
                } else {
                    self.percent = 0
                }
            }
    }
""", with: """
                } else {
                    self.percent = 0
                }
            }
        }
    }
""")
try! content.write(to: url, atomically: true, encoding: .utf8)
