import AVFoundation

var engine: AVAudioEngine? = AVAudioEngine()
var player: AVAudioPlayerNode? = AVAudioPlayerNode()
engine?.attach(player!)
engine?.connect(player!, to: engine!.mainMixerNode, format: nil)
try! engine?.start()
print("Started 1")

let id: AudioDeviceID = 0
engine?.stop()
player = nil
engine = nil

engine = AVAudioEngine()
player = AVAudioPlayerNode()

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

engine?.attach(player!)
engine?.connect(player!, to: engine!.mainMixerNode, format: nil)

do {
    try engine?.start()
    print("Success after full recreate")
} catch {
    print("Error: \(error)")
}
