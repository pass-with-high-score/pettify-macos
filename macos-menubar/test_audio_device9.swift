import AVFoundation

var engine: AVAudioEngine? = AVAudioEngine()
let player = AVAudioPlayerNode()
engine?.attach(player)
engine?.connect(player, to: engine!.mainMixerNode, format: nil)
try! engine?.start()
print("Started 1")

let id: AudioDeviceID = 0
engine?.stop()
engine = nil

engine = AVAudioEngine()
let unit = engine!.outputNode.audioUnit!
var deviceID = id
AudioUnitSetProperty(
    unit,
    kAudioOutputUnitProperty_CurrentDevice,
    kAudioUnitScope_Global,
    0,
    &deviceID,
    UInt32(MemoryLayout<AudioDeviceID>.size)
)

engine?.attach(player)
engine?.connect(player, to: engine!.mainMixerNode, format: nil)

do {
    try engine?.start()
    print("Success after recreate")
} catch {
    print("Error: \(error)")
}
