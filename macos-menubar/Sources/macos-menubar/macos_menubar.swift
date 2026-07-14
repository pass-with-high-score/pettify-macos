import Cocoa
import SwiftUI

struct TrackStatus: Decodable {
    var title: String
    var artist: String
    var thumbnail: String
    var paused: Bool
    var volume: Double
    var percent: Double
    var position: Double
    var duration: Double
}

@MainActor
class AppState: ObservableObject {
    @Published var status = TrackStatus(title: "Loading...", artist: "", thumbnail: "", paused: false, volume: 1.0, percent: 0, position: 0, duration: 0)
    
    func fetch() {
        guard let url = URL(string: "http://localhost:13337/status") else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let s = try? JSONDecoder().decode(TrackStatus.self, from: data) {
                    self.status = s
                }
            } catch {}
        }
    }
    
    func post(_ endpoint: String) {
        guard let url = URL(string: "http://localhost:13337/\(endpoint)") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        Task {
            do {
                _ = try await URLSession.shared.data(for: req)
                try await Task.sleep(nanoseconds: 200_000_000)
                self.fetch()
            } catch {}
        }
    }
}

struct PopoverView: View {
    @StateObject var state = AppState()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 15) {
            if state.status.thumbnail != "" {
                AsyncImage(url: URL(string: state.status.thumbnail)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Color.black.opacity(0.2)
                    }
                }.frame(width: 220, height: 124).cornerRadius(12).shadow(radius: 5)
            } else {
                Color.black.opacity(0.2).frame(width: 220, height: 124).cornerRadius(12)
            }
            
            VStack(spacing: 5) {
                Text(state.status.title).font(.headline).lineLimit(1).frame(maxWidth: 220)
                if state.status.artist != "" {
                    Text(state.status.artist).font(.subheadline).foregroundColor(.secondary).lineLimit(1).frame(maxWidth: 220)
                }
            }
            
            HStack(spacing: 30) {
                Button(action: { state.post("prev") }) { 
                    Image(systemName: "backward.fill").font(.title2) 
                }.buttonStyle(.plain)
                
                Button(action: { state.post("playpause") }) { 
                    Image(systemName: state.status.paused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 44)) 
                }.buttonStyle(.plain)
                
                Button(action: { state.post("next") }) { 
                    Image(systemName: "forward.fill").font(.title2) 
                }.buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(width: 260, height: 280)
        .background(VisualEffectView().edgesIgnoringSafeArea(.all))
        .onReceive(timer) { _ in state.fetch() }
        .onAppear { state.fetch() }
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .popover
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

@main
struct MenuBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = PopoverView()
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Audio CLI")
            button.action = #selector(togglePopover(_:))
        }
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}
