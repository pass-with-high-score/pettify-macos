import AVFoundation

let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: nil)
try! engine.start()

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
    
    engine.reset()
    
    do {
        try engine.start()
        print("Success")
    } catch {
        print("Error: \(error)")
    }
}
