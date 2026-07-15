import AVFoundation

func getDefaultOutputDevice() -> AudioDeviceID {
    var deviceID = kAudioObjectUnknown
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
        &deviceID
    )
    return deviceID
}

let id = getDefaultOutputDevice()

let engine = AVAudioEngine()
let player = AVAudioPlayerNode()
engine.attach(player)
engine.connect(player, to: engine.mainMixerNode, format: nil)
try! engine.start()
print("Started 1")

let unit = engine.outputNode.audioUnit!
var deviceID = id
engine.pause()

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
