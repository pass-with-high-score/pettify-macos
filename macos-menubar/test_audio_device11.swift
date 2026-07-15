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
print("Default device id: \(id)")

var engine: AVAudioEngine? = AVAudioEngine()
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
do {
    try engine?.start()
    print("Success")
} catch {
    print("Error: \(error)")
}
