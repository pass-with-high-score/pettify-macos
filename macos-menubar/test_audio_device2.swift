import AVFoundation

let engine = AVAudioEngine()
let id: AudioDeviceID = 0
do {
    engine.outputNode.auAudioUnit.deviceID = id
    print("Success")
} catch {
    print("Error: \(error)")
}
