import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @AppStorage("showFloatingLyrics") private var showFloatingLyrics = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("showDockIcon") private var showDockIcon = false
    
    @AppStorage("floatingOpacity") private var floatingOpacity = 1.0
    @AppStorage("floatingFontSize") private var floatingFontSize = 36.0
    
    @AppStorage("nekoSkin") private var nekoSkin = "neko"
    
    @AppStorage("audioQuality") private var audioQuality = "bestaudio"
    @AppStorage("defaultVolume") private var defaultVolume = 1.0
    
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
                            alert.informativeText = "Please restart Audio CLI for the Dock Icon setting to take effect."
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
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Desktop Pet Skin").bold()
                        Picker("", selection: $nekoSkin) {
                            ForEach(availableSkins, id: \.self) { skin in
                                Text(skin.capitalized).tag(skin)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
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
            
            GroupBox("Audio Effects") {
                VStack(spacing: 20) {
                    // Playback Speed
                    VStack(alignment: .leading, spacing: 8) {
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
                    }
                    
                    Divider()
                    
                    // Pitch Shift
                    VStack(alignment: .leading, spacing: 8) {
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
