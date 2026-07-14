import AVFoundation

let engine = AVAudioEngine()
let id: AudioDeviceID = 0
if let unit = engine.outputNode.audioUnit {
    var deviceID = id
    let wasPlaying = engine.isRunning
    engine.stop()
    AudioUnitSetProperty(
        unit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &deviceID,
        UInt32(MemoryLayout<AudioDeviceID>.size)
    )
    do {
        try engine.start()
        print("Success")
    } catch {
        print("Error: \(error)")
    }
}
