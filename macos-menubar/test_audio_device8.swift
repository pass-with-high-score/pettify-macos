import AVFoundation

let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
let timePitch = AVAudioUnitTimePitch()

engine.attach(player)
engine.attach(timePitch)
engine.connect(player, to: timePitch, format: nil)
engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
try! engine.start()
print("Started")

let id: AudioDeviceID = 0
if let unit = engine.outputNode.audioUnit {
    var deviceID = id
    engine.stop()
    
    engine.disconnectNodeInput(timePitch)
    engine.disconnectNodeInput(engine.mainMixerNode)
    
    AudioUnitSetProperty(
        unit,
        kAudioOutputUnitProperty_CurrentDevice,
        kAudioUnitScope_Global,
        0,
        &deviceID,
        UInt32(MemoryLayout<AudioDeviceID>.size)
    )
    
    engine.connect(player, to: timePitch, format: nil)
    engine.connect(timePitch, to: engine.mainMixerNode, format: nil)
    
    do {
        try engine.start()
        print("Success")
    } catch {
        print("Error: \(error)")
    }
}
