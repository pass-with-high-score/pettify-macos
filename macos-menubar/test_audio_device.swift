import AVFoundation

let engine = AVAudioEngine()
let id: AudioDeviceID = 0
if let unit = engine.outputNode.audioUnit {
    print("Found unit")
}
