import Foundation
import AVFoundation
import MediaPlayer

@MainActor
class AudioPlayer: ObservableObject {
    static let shared = AudioPlayer()
    private var player: AVPlayer?
    private var timeObserverToken: Any?
    
    @Published var paused: Bool = false
    @Published var volume: Double = 1.0 {
        didSet { player?.volume = Float(volume) }
    }
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var percent: Double = 0
    
    var onFinish: (() -> Void)?
    
    init() {
        setupAudioSession()
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    @objc private func playerDidFinishPlaying(note: Notification) {
        if let currentItem = player?.currentItem, let object = note.object as? AVPlayerItem, object == currentItem {
            onFinish?()
        }
    }
    
    private func setupAudioSession() {
        // macOS doesn't have AVAudioSession the exact same way as iOS,
        // but AVPlayer just works out of the box for playback in background if we don't suspend.
    }
    
    func play(url stringURL: String) {
        guard let url = URL(string: stringURL) else { return }
        
        let item = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }
        
        player?.volume = Float(volume)
        player?.play()
        paused = false
        
        setupTimeObserver()
    }
    
    private func setupTimeObserver() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, let player = self.player, let currentItem = player.currentItem else { return }
                
                let pos = time.seconds
                let dur = currentItem.duration.seconds
                
                self.position = pos.isNaN ? 0 : pos
                self.duration = dur.isNaN ? 0 : dur
                
                if self.duration > 0 {
                    self.percent = (self.position / self.duration) * 100
                } else {
                    self.percent = 0
                }
            }
        }
    }
    
    func togglePlayPause() {
        if paused {
            player?.play()
        } else {
            player?.pause()
        }
        paused.toggle()
    }
    
    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
    }
}
