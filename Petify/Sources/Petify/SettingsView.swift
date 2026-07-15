import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("showFloatingLyrics") private var showFloatingLyrics = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showDockIcon") private var showDockIcon = false
    
    @AppStorage("floatingOpacity") private var floatingOpacity = 1.0
    @AppStorage("floatingFontSize") private var floatingFontSize = 36.0
    @AppStorage("lyricsAnimation") private var lyricsAnimation = "slide"
    @AppStorage("lyricsFont") private var lyricsFont = "rounded"
    @AppStorage("lyricsColor") private var lyricsColor = "white"
    
    @AppStorage("nekoSkin") private var nekoSkin = "neko"
    @AppStorage("nekoSpeed") private var nekoSpeed = 4.0
    @AppStorage("nekoSize") private var nekoSize = 32.0
    @AppStorage("nekoWallClaw") private var nekoWallClaw = true
    @AppStorage("nekoScreenEdge") private var nekoScreenEdge = false
    
    @AppStorage("audioQuality") private var audioQuality = "bestaudio"
    @AppStorage("defaultVolume") private var defaultVolume = 1.0
    @AppStorage("eqPreset") private var eqPreset = "Flat"
    
    @AppStorage("maxCacheSizeGB") private var maxCacheSizeGB = 2.0
    
    @State private var cacheSize: String = "Calculating..."
    @State private var selectedTab: String = "general"
    
    @ObservedObject var state: AppState
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 5) {
                SidebarItem(title: "General", icon: "gear", isSelected: selectedTab == "general") { selectedTab = "general" }
                SidebarItem(title: "Appearance", icon: "paintpalette", isSelected: selectedTab == "appearance") { selectedTab = "appearance" }
                SidebarItem(title: "Playback", icon: "play.circle", isSelected: selectedTab == "playback") { selectedTab = "playback" }
                SidebarItem(title: "Storage", icon: "externaldrive", isSelected: selectedTab == "storage") { selectedTab = "storage" }
                SidebarItem(title: "About", icon: "info.circle", isSelected: selectedTab == "about") { selectedTab = "about" }
                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 10)
            .frame(width: 160)
            .background(VisualEffectView().edgesIgnoringSafeArea(.all)) // Translucent sidebar
            
            Divider()
            
            // Content
            ScrollView {
                VStack(alignment: .leading) {
                    switch selectedTab {
                    case "general":
                        generalContent
                    case "appearance":
                        appearanceContent
                    case "playback":
                        playbackContent
                    case "storage":
                        storageContent
                    case "about":
                        aboutContent
                    default:
                        EmptyView()
                    }
                }
                .padding(30)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 600, height: 400)
    }
    
    // MARK: - Sidebar Item Component
    struct SidebarItem: View {
        let title: String
        let icon: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                HStack {
                    Image(systemName: icon)
                        .frame(width: 20)
                        .foregroundColor(isSelected ? .white : .primary)
                    Text(title)
                        .foregroundColor(isSelected ? .white : .primary)
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(isSelected ? Color.accentColor : Color.clear)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 20) {
                Image(nsImage: Bundle.module.image(forResource: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 80, height: 80)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Petify")
                        .font(.largeTitle)
                        .bold()
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                    Text("A premium, lightweight music player for macOS.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 10)
            
            GroupBox("Keyboard Shortcuts") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Play / Pause")
                        Spacer()
                        Text("Space").padding(4).background(Color.secondary.opacity(0.2)).cornerRadius(4)
                    }
                    Divider()
                    HStack {
                        Text("Next Track")
                        Spacer()
                        Text("Right Arrow").padding(4).background(Color.secondary.opacity(0.2)).cornerRadius(4)
                    }
                    Divider()
                    HStack {
                        Text("Previous Track")
                        Spacer()
                        Text("Left Arrow").padding(4).background(Color.secondary.opacity(0.2)).cornerRadius(4)
                    }
                }
                .padding(12)
            }
            
            VStack(alignment: .center) {
                Spacer()
                Text("Made with ❤️ by Antigravity")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // MARK: - Tab Contents
    
    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General").font(.title2).bold()
            
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at Login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            if #available(macOS 13.0, *) {
                                if newValue {
                                    try? SMAppService.mainApp.register()
                                } else {
                                    try? SMAppService.mainApp.unregister()
                                }
                            }
                        }
                    
                    Toggle("Show Dock Icon (requires app restart)", isOn: $showDockIcon)
                        .onChange(of: showDockIcon) { _ in
                            let alert = NSAlert()
                            alert.messageText = "Restart Required"
                            alert.informativeText = "Please restart Petify for the Dock Icon setting to take effect."
                            alert.alertStyle = .informational
                            alert.addButton(withTitle: "OK")
                            alert.runModal()
                        }
                    
                    Toggle("Show Floating Lyrics Window", isOn: $showFloatingLyrics)
                        .onChange(of: showFloatingLyrics) { newValue in
                            NotificationCenter.default.post(name: NSNotification.Name("ToggleFloatingLyrics"), object: newValue)
                        }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Appearance").font(.title2).bold()
            
            GroupBox {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Floating Lyrics Opacity: \(Int(floatingOpacity * 100))%").bold()
                        Slider(value: $floatingOpacity, in: 0.1...1.0, step: 0.05)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Floating Lyrics Font Size: \(Int(floatingFontSize))").bold()
                        Picker("", selection: $floatingFontSize) {
                            Text("Small").tag(24.0)
                            Text("Medium").tag(36.0)
                            Text("Large").tag(48.0)
                            Text("Extra Large").tag(64.0)
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lyrics Font Style:").bold()
                        Picker("", selection: $lyricsFont) {
                            Text("Rounded").tag("rounded")
                            Text("Standard").tag("default")
                            Text("Serif").tag("serif")
                            Text("Monospaced").tag("monospaced")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lyrics Color:").bold()
                        Picker("", selection: $lyricsColor) {
                            Text("White").tag("white")
                            Text("Dynamic (Album Art)").tag("dynamic")
                            Text("Yellow").tag("yellow")
                            Text("Pink").tag("pink")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lyrics Animation:").bold()
                        Picker("", selection: $lyricsAnimation) {
                            Text("Slide").tag("slide")
                            Text("Scale").tag("scale")
                            Text("Blur").tag("blur")
                            Text("3D Flip").tag("3d")
                            Text("Random / Song").tag("randomPerSong")
                            Text("Random / Line").tag("randomPerLine")
                        }
                        .pickerStyle(.menu)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Desktop Pet Settings").font(.headline)
                        
                        Picker("Pet Mode", selection: $nekoScreenEdge) {
                            Text("Inside Lyrics Window").tag(false)
                            Text("Screen Edge (Full Desktop)").tag(true)
                        }
                        .pickerStyle(.radioGroup)
                        .onChange(of: nekoScreenEdge) { newValue in
                            NotificationCenter.default.post(name: NSNotification.Name("ToggleNekoMode"), object: newValue)
                        }
                        
                        Toggle("Enable Wall Clawing Animation", isOn: $nekoWallClaw)
                        
                        HStack {
                            Text("Pet Speed")
                            Slider(value: $nekoSpeed, in: 1.0...10.0, step: 1.0)
                            Text(String(format: "%.0f", nekoSpeed)).monospacedDigit().frame(width: 30)
                        }
                        
                        HStack {
                            Text("Pet Size")
                            Slider(value: $nekoSize, in: 16.0...64.0, step: 8.0)
                            Text(String(format: "%.0f", nekoSize)).monospacedDigit().frame(width: 30)
                        }
                        
                        Text("Choose Pet Skin").font(.subheadline).bold().padding(.top, 8)
                        
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 16) {
                                ForEach(availableSkins, id: \.self) { skin in
                                    VStack {
                                        ZStack {
                                            if skin == nekoSkin {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.accentColor.opacity(0.3))
                                                    .frame(width: 56, height: 56)
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.accentColor, lineWidth: 2)
                                                    .frame(width: 56, height: 56)
                                            } else {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.secondary.opacity(0.1))
                                                    .frame(width: 56, height: 56)
                                            }
                                            
                                            if let url = Bundle.module.url(forResource: "awake", withExtension: "png", subdirectory: "Skins/\(skin)"),
                                               let nsImage = NSImage(contentsOf: url) {
                                                Image(nsImage: nsImage)
                                                    .resizable()
                                                    .interpolation(.none)
                                                    .frame(width: 32, height: 32)
                                            } else if let fallbackUrl = Bundle.module.url(forResource: "awake", withExtension: "png", subdirectory: "Skins/neko"),
                                                      let fallbackImage = NSImage(contentsOf: fallbackUrl) {
                                                Image(nsImage: fallbackImage)
                                                    .resizable()
                                                    .interpolation(.none)
                                                    .frame(width: 32, height: 32)
                                            }
                                        }
                                        Text(skin.capitalized)
                                            .font(.system(size: 10))
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                    }
                                    .onTapGesture {
                                        withAnimation { nekoSkin = skin }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                        }
                        .frame(height: 200)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private var playbackContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Playback Settings").font(.title2).bold()
            
            GroupBox("General") {
                VStack(spacing: 16) {
                    HStack {
                        Text("Audio Quality")
                        Spacer()
                        Picker("", selection: $audioQuality) {
                            Text("Best Audio").tag("bestaudio")
                            Text("256 kbps (High Quality)").tag("256k")
                            Text("128 kbps (Data Saver)").tag("128k")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                    }
                    
                    HStack {
                        Text("Default Volume")
                        Spacer()
                        HStack {
                            Image(systemName: "speaker.fill").foregroundColor(.secondary).font(.caption)
                            Slider(value: $defaultVolume, in: 0.0...1.0, step: 0.05)
                                .frame(width: 150)
                            Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary).font(.caption)
                        }
                        Text("\(Int(defaultVolume * 100))%")
                            .frame(width: 45, alignment: .trailing)
                            .monospacedDigit()
                    }
                    
                    HStack {
                        Text("Output Device")
                        Spacer()
                        let devices = state.audioPlayer.getOutputDevices()
                        Picker("", selection: Binding(
                            get: { return Int(state.audioPlayer.currentOutputDeviceID) },
                            set: { id in state.audioPlayer.setOutputDevice(id: UInt32(id)) }
                        )) {
                            Text("System Default").tag(0)
                            Divider()
                            ForEach(devices, id: \.id) { device in
                                Text(device.name).tag(Int(device.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 220)
                    }
                }
                .padding(12)
            }
            
            GroupBox("Equalizer") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Preset")
                        Spacer()
                        Picker("", selection: $eqPreset) {
                            ForEach(EQPreset.allCases, id: \.self) { preset in
                                Text(preset.rawValue).tag(preset.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                        .onChange(of: eqPreset) { newValue in
                            if let preset = EQPreset(rawValue: newValue) {
                                state.audioPlayer.applyEQPreset(preset)
                            }
                        }
                    }
                    
                    // 10-Band EQ UI
                    let frequencies = ["32", "64", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
                    HStack(spacing: 8) {
                        ForEach(0..<10, id: \.self) { index in
                            VStack(spacing: 6) {
                                let gain = state.audioPlayer.eqBands[index]
                                Text(String(format: "%.0f", gain))
                                    .font(.system(size: 9))
                                    .foregroundColor(.secondary)
                                    .frame(height: 12)
                                
                                Slider(value: Binding(
                                    get: { gain },
                                    set: { val in
                                        eqPreset = "Custom"
                                        state.audioPlayer.setEQBand(index: index, gain: val)
                                    }
                                ), in: -24.0...24.0)
                                .frame(height: 100)
                                .rotationEffect(.degrees(-90))
                                .frame(width: 20, height: 100)
                                
                                Text(frequencies[index])
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    HStack {
                        Spacer()
                        Button("Reset to Flat") {
                            eqPreset = "Flat"
                            state.audioPlayer.applyEQPreset(.flat)
                        }
                        .buttonStyle(.link)
                        .font(.caption)
                    }
                }
                .padding(12)
            }
            
            GroupBox("Audio Effects") {
                VStack(spacing: 20) {
                    // Playback Speed
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Playback Speed")
                            Spacer()
                            Text(String(format: "%.2fx", state.audioPlayer.rate))
                                .monospacedDigit()
                                .foregroundColor(.accentColor)
                            Button(action: { state.audioPlayer.rate = 1.0 }) {
                                Image(systemName: "arrow.counterclockwise.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Reset to 1.0x")
                        }
                        
                        HStack {
                            Image(systemName: "tortoise.fill").foregroundColor(.secondary).font(.caption)
                            Slider(value: $state.audioPlayer.rate, in: 0.5...2.0, step: 0.05)
                            Image(systemName: "hare.fill").foregroundColor(.secondary).font(.caption)
                        }
                        
                        HStack(spacing: 8) {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { val in
                                Button("\(val, specifier: "%.2f")x") {
                                    state.audioPlayer.rate = Float(val)
                                }
                                .font(.system(size: 10))
                                .buttonStyle(.borderless)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(state.audioPlayer.rate == Float(val) ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(state.audioPlayer.rate == Float(val) ? .white : .primary)
                                .cornerRadius(4)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Pitch Shift
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Pitch Shift")
                            Spacer()
                            let semitones = Int(state.audioPlayer.pitch / 100)
                            let sign = semitones > 0 ? "+" : ""
                            Text("\(sign)\(semitones) semitones")
                                .monospacedDigit()
                                .foregroundColor(.accentColor)
                            Button(action: { state.audioPlayer.pitch = 0.0 }) {
                                Image(systemName: "arrow.counterclockwise.circle")
                            }
                            .buttonStyle(.plain)
                            .help("Reset to 0")
                        }
                        
                        HStack {
                            Text("-12").foregroundColor(.secondary).font(.caption)
                            Slider(value: $state.audioPlayer.pitch, in: -1200...1200, step: 100)
                            Text("+12").foregroundColor(.secondary).font(.caption)
                        }
                        
                        HStack(spacing: 8) {
                            ForEach([-12, -2, 0, 2, 12], id: \.self) { val in
                                let sign = val > 0 ? "+" : ""
                                Button("\(sign)\(val)") {
                                    state.audioPlayer.pitch = Float(val * 100)
                                }
                                .font(.system(size: 10))
                                .buttonStyle(.borderless)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Int(state.audioPlayer.pitch/100) == val ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(Int(state.audioPlayer.pitch/100) == val ? .white : .primary)
                                .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(12)
            }
            
            GroupBox("Sleep Timer") {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Stop playing after:")
                        Spacer()
                        Picker("", selection: $state.sleepTimerMinutes) {
                            Text("Off").tag(0)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("45 minutes").tag(45)
                            Text("60 minutes").tag(60)
                            Text("90 minutes").tag(90)
                            Text("120 minutes").tag(120)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    if state.sleepTimerMinutes > 0 {
                        HStack {
                            Image(systemName: "timer")
                            let remaining = state.sleepTimerRemainingSeconds
                            let m = remaining / 60
                            let s = remaining % 60
                            Text(String(format: "%02d:%02d remaining", m, s))
                                .monospacedDigit()
                            Spacer()
                            Button("Cancel") {
                                state.sleepTimerMinutes = 0
                            }
                            .buttonStyle(.link)
                        }
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    }
                }
                .padding(12)
            }
        }
    }
    
    private var storageContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Storage & Cache").font(.title2).bold()
            
            GroupBox {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Current Audio Cache:").bold()
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.secondary)
                    }
                    .onAppear(perform: calculateCacheSize)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Max Auto-Cleanup Size: \(String(format: "%.1f", maxCacheSizeGB)) GB").bold()
                        Slider(value: $maxCacheSizeGB, in: 0.5...10.0, step: 0.5)
                        Text("When the cache exceeds this limit, older downloaded songs will be automatically deleted to save space.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: clearCache) {
                        Text("Clear Cache Now")
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func calculateCacheSize() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("audio-cli-yt")
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.fileSizeKey]) else {
            cacheSize = "0 MB"
            return
        }
        
        var totalSize: Int64 = 0
        for file in files {
            if let attrs = try? FileManager.default.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        
        let mb = Double(totalSize) / (1024 * 1024)
        cacheSize = String(format: "%.1f MB", mb)
    }
    
    private func clearCache() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("audio-cli-yt")
        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        calculateCacheSize()
    }
    
    private var availableSkins: [String] {
        if let url = Bundle.module.url(forResource: "Skins", withExtension: nil) {
            if let dirs = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
                return dirs.filter { !$0.hasPrefix(".") }.sorted()
            }
        }
        return ["neko"]
    }
}
