import Cocoa
import SwiftUI
import MediaPlayer

struct PopoverView: View {
    @ObservedObject var state: AppState
    @State private var searchQuery: String = ""
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                TextField("Search YouTube or Add URL...", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        if !searchQuery.isEmpty {
                            state.addTrack(query: searchQuery)
                            searchQuery = ""
                        }
                    }
                Button(action: {
                    if !searchQuery.isEmpty {
                        state.addTrack(query: searchQuery)
                        searchQuery = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill").foregroundColor(.accentColor).font(.title2)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            if state.status.searchStatus != "" {
                Text(state.status.searchStatus)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .transition(.opacity)
            }
            
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
                    .help(state.status.title)
                if state.status.artist != "" {
                    Text(state.status.artist).font(.subheadline).foregroundColor(.secondary).lineLimit(1).frame(maxWidth: 220)
                        .help(state.status.artist)
                }
            }
            
            if !state.lyrics.isEmpty {
                VStack(spacing: 6) {
                    if state.currentLyricIndex >= 0 && state.currentLyricIndex < state.lyrics.count {
                        Text(state.lyrics[state.currentLyricIndex].text)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .id(state.lyrics[state.currentLyricIndex].id) // force transition
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Text("♪").font(.system(size: 15)).foregroundColor(.secondary)
                    }
                    
                    if state.currentLyricIndex + 1 < state.lyrics.count {
                        Text(state.lyrics[state.currentLyricIndex + 1].text)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                }
                .frame(height: 50)
                .animation(.easeInOut(duration: 0.3), value: state.currentLyricIndex)
            }
            
            HStack(spacing: 8) {
                Text(state.formatTime(state.status.position))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
                    
                CustomSlider(value: Binding(get: {
                    state.status.position
                }, set: { val in
                    state.status.position = val
                    state.seek(to: val)
                }), total: max(0.1, state.status.duration))
                
                Text(state.formatTime(state.status.duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundColor(.secondary)
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
            
            HStack {
                Image(systemName: "speaker.fill").foregroundColor(.secondary).font(.caption2)
                CustomSlider(value: Binding(get: {
                    state.status.volume
                }, set: { val in
                    state.status.volume = val
                    state.setVolume(val)
                }), total: 1.0)
                .frame(width: 80)
                Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary).font(.caption2)
            }
        }
        .padding(20)
        .frame(width: 260, height: state.lyrics.isEmpty ? 350 : 450)
        .background(VisualEffectView().edgesIgnoringSafeArea(.all))
    }
}
