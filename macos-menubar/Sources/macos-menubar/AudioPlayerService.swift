import AVFoundation
import CoreAudio
import Foundation

@MainActor
final class AudioPlayerService: NSObject, ObservableObject {

    // MARK: Published State

    @Published var isPlaying: Bool = false
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0
    @Published var volume: Float = 1.0

    // Audio Engine Properties
    @Published var pitch: Float = 0.0 { // cents (100 cents = 1 semitone)
        didSet { timePitch.pitch = pitch }
    }
    @Published var rate: Float = 1.0 { // 1.0 = normal
        didSet { timePitch.rate = rate }
    }
    
    @Published var currentOutputDeviceID: AudioDeviceID = 0
    
    @Published var eqBands: [Float] = Array(repeating: 0.0, count: 10) {
        didSet {
            guard eqBands.count == eq.bands.count else { return }
            for i in 0..<eq.bands.count {
                eq.bands[i].gain = eqBands[i]
            }
        }
    }
    
    private var hasLoadedFile: Bool = false
    
    // MARK: Callback

    /// Called on the main actor when the current track finishes playing naturally.
    var onTrackFinished: (() -> Void)?

    // MARK: Private

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private let eq = AVAudioUnitEQ(numberOfBands: 10)
    
    private var progressTimer: Timer?
    private var currentAudioFile: AVAudioFile?
    private var seekTimeOffset: Double = 0.0
    private var playbackToken = UUID()

    override init() {
        super.init()
        setupEngine()
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.attach(timePitch)
        engine.attach(eq)
        
        let format = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: timePitch, format: format)
        engine.connect(timePitch, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        
        // Setup default EQ bands (flat)
        let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for i in 0..<eq.bands.count {
            eq.bands[i].filterType = .parametric
            eq.bands[i].frequency = frequencies[i]
            eq.bands[i].bandwidth = 1.0
            eq.bands[i].gain = 0.0
            eq.bands[i].bypass = false
        }
        
        engine.prepare()
        try? engine.start()
    }

    // MARK: - Playback Controls

    func play(fileURL: URL) {
        stopProgressTimer()
        playbackToken = UUID() // invalidate previous
        playerNode.stop()
        
        do {
            let file = try AVAudioFile(forReading: fileURL)
            currentAudioFile = file
            duration = Double(file.length) / file.processingFormat.sampleRate
            currentTime = 0.0
            seekTimeOffset = 0.0
            hasLoadedFile = true
            
            if !engine.isRunning {
                try engine.start()
            }
            
            
            let token = UUID()
            playbackToken = token
            
            playerNode.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor in
                    self?.handlePlaybackFinished(token: token)
                }
            }
            
            engine.mainMixerNode.outputVolume = volume
            playerNode.play()
            isPlaying = true
            startProgressTimer()
        } catch {
            isPlaying = false
            duration = 0.0
            currentTime = 0.0
            print("[AudioPlayerService] Failed to play file: \(error.localizedDescription)")
        }
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
        updateCurrentTime()
        stopProgressTimer()
    }

    func resume() {
        guard !isPlaying, hasLoadedFile else { return }
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
        isPlaying = true
        startProgressTimer()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func seek(to seconds: Double) {
        guard let file = currentAudioFile else { return }
        let clamped = max(0, min(seconds, duration))
        
        playbackToken = UUID() // invalidate current playback
        playerNode.stop()
        
        seekTimeOffset = clamped
        currentTime = clamped
        
        let sampleRate = file.processingFormat.sampleRate
        let newSampleTime = AVAudioFramePosition(clamped * sampleRate)
        let framesToPlay = AVAudioFrameCount(file.length - newSampleTime)
        
        if framesToPlay > 0 {
            let token = UUID()
            playbackToken = token
            
            playerNode.scheduleSegment(file, startingFrame: newSampleTime, frameCount: framesToPlay, at: nil) { [weak self] in
                Task { @MainActor in
                    self?.handlePlaybackFinished(token: token)
                }
            }
        } else {
            handlePlaybackFinished(token: playbackToken)
        }
        
        if isPlaying {
            playerNode.play()
        }
    }

    func setVolume(_ newVolume: Float) {
        let clamped = max(0.0, min(1.0, newVolume))
        volume = clamped
        engine.mainMixerNode.outputVolume = clamped
    }
    
    func setEQBand(index: Int, gain: Float) {
        guard index >= 0 && index < eqBands.count else { return }
        eqBands[index] = max(-24.0, min(24.0, gain))
    }
    
    func applyEQPreset(_ preset: EQPreset) {
        guard preset != .custom else { return }
        let gains = preset.gains
        guard gains.count == eqBands.count else { return }
        eqBands = gains
    }

    func stop() {
        stopProgressTimer()
        playbackToken = UUID()
        playerNode.stop()
        isPlaying = false
        currentTime = 0.0
        duration = 0.0
        hasLoadedFile = false
    }
    
    private func handlePlaybackFinished(token: UUID) {
        Task { @MainActor in
            guard token == self.playbackToken else { return }
            self.isPlaying = false
            self.stopProgressTimer()
            self.onTrackFinished?()
        }
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCurrentTime()
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateCurrentTime() {
        guard isPlaying, let nodeTime = playerNode.lastRenderTime, let playerTime = playerNode.playerTime(forNodeTime: nodeTime) else { return }
        let playedTime = Double(playerTime.sampleTime) / playerTime.sampleRate
        currentTime = seekTimeOffset + playedTime
        
        // Cap at duration
        if currentTime >= duration && duration > 0 {
            currentTime = duration
        }
    }

    // MARK: - Output Device Selection
    
    struct AudioDevice: Hashable {
        let id: AudioDeviceID
        let name: String
    }
    
    func getOutputDevices() -> [AudioDevice] {
        var propsize: UInt32 = 0
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize)
        guard result == 0 else { return [] }
        
        let deviceCount = Int(propsize / UInt32(MemoryLayout<AudioDeviceID>.size))
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        
        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propsize, &deviceIDs)
        guard result == 0 else { return [] }
        
        var devices: [AudioDevice] = []
        
        for id in deviceIDs {
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize)
            if streamSize > 0 {
                var nameAddress = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                var nameCF: CFString = "" as CFString
                var nameSize = UInt32(MemoryLayout<CFString>.size)
                AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &nameCF)
                let name = nameCF as String
                devices.append(AudioDevice(id: id, name: name))
            }
        }
        return devices
    }
    
    func setOutputDevice(id: AudioDeviceID) {
        guard let outputUnit = engine.outputNode.audioUnit else { return }
        var deviceID = id
        
        var actualDeviceID = id
        if id == 0 {
            var propsize = UInt32(MemoryLayout<AudioDeviceID>.size)
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &propsize,
                &actualDeviceID
            )
        }
        
        // Update the published state
        Task { @MainActor in
            self.currentOutputDeviceID = id
        }
        
        let wasPlaying = self.isPlaying
        let pos = self.currentTime
        
        if wasPlaying {
            self.pause()
        }
        
        AudioUnitSetProperty(
            outputUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &actualDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        
        if wasPlaying {
            do {
                try engine.start()
                self.seek(to: pos)
                self.resume()
            } catch {
                print("Failed to restart engine after changing device: \(error)")
            }
        }
    }
}
