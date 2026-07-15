import AVFoundation

let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: nil)
try! engine.start()
print("Started")

let id: AudioDeviceID = 0
if let unit = engine.outputNode.audioUnit {
    var deviceID = id
    engine.stop()
    AudioUnitSetProperty(
        unit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &deviceID,
        UInt32(MemoryLayout<AudioDeviceID>.size)
    )
    
    // Attempt to reconfigure
    // engine.connect(engine.mainMixerNode, to: engine.outputNode, format: nil)
    
    do {
        try engine.start()
        print("Success 2")
    } catch {
        print("Error: \(error)")
    }
}
