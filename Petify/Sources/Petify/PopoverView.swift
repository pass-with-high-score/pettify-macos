import Cocoa
import SwiftUI
import MediaPlayer

struct PopoverView: View {
    @ObservedObject var state: AppState
    @State private var searchQuery: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var showLibrary: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // 1. Search Bar
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Search or paste YouTube URL...", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit { submitSearch() }
                
                if !state.status.searchStatus.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.5)
                        .frame(width: 16, height: 16)
                } else if !searchQuery.isEmpty {
                    Button(action: submitSearch) {
                        Image(systemName: "return")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.secondary.opacity(0.15))
            .cornerRadius(8)
            
            HStack {
                Spacer()
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenKaraoke"), object: nil)
                }) {
                    Image(systemName: "music.mic")
                        .foregroundColor(.accentColor)
                        .font(.system(size: 14))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Karaoke Mode")
                
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Settings")
                
                Button(action: {
                    NotificationCenter.default.post(name: NSNotification.Name("QuitApp"), object: nil)
                }) {
                    Image(systemName: "power")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Quit")
            }
            .padding(.top, -4)
            .padding(.trailing, 4)
            
            // 2. Now Playing Card
            ZStack(alignment: .bottomLeading) {
                if state.status.thumbnail != "" {
                    if state.status.thumbnail.hasPrefix("file://"), let url = URL(string: state.status.thumbnail), let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 290, height: 164)
                            .clipped()
                    } else {
                        AsyncImage(url: URL(string: state.status.thumbnail)) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Color.black.opacity(0.3)
                            }
                        }.frame(width: 290, height: 164).clipped()
                    }
                } else {
                    Color.black.opacity(0.3).frame(width: 290, height: 164)
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                        .position(x: 145, y: 82)
                }
                
                // Gradient overlay
                VStack {
                    Spacer()
                    LinearGradient(gradient: Gradient(colors: [.clear, .black.opacity(0.8)]), startPoint: .top, endPoint: .bottom)
                        .frame(height: 80)
                }
                
                // Text and Download Button
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.status.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .lineLimit(1)
                        if !state.status.artist.isEmpty {
                            Text(state.status.artist)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.85))
                                .shadow(radius: 2)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if state.currentTrackIndex >= 0 && state.currentTrackIndex < state.tracks.count && !state.tracks[state.currentTrackIndex].url.hasPrefix("file://") {
                        Button(action: {
                            state.saveCurrentTrackOffline()
                        }) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .buttonStyle(.plain)
                        .help("Download for offline playback")
                    }
                }
                .padding(12)
                
                // Search status overlay (if downloading)
                if !state.status.searchStatus.isEmpty {
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                            .padding(.bottom, 2)
                        Text(state.status.searchStatus)
                            .font(.caption)
                            .foregroundColor(.white)
                            .bold()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    .frame(width: 290, height: 164)
                    .background(Color.black.opacity(0.6))
                    .transition(.opacity)
                }
            }
            .frame(width: 290, height: 164)
            .cornerRadius(14)
            .animation(.easeInOut(duration: 0.2), value: state.status.searchStatus)
            
            // 3. Lyrics
            if !state.lyrics.isEmpty {
                VStack(spacing: 4) {
                    if state.currentLyricIndex >= 0 && state.currentLyricIndex < state.lyrics.count {
                        Text(state.lyrics[state.currentLyricIndex].text)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(state.dominantColor != .white ? state.dominantColor : .accentColor)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .id(state.lyrics[state.currentLyricIndex].id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    } else {
                        Text("♪").font(.system(size: 14)).foregroundColor(.secondary)
                    }
                    
                    if state.currentLyricIndex + 1 < state.lyrics.count {
                        Text(state.lyrics[state.currentLyricIndex + 1].text)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                }
                .frame(height: 44)
                .animation(.easeInOut(duration: 0.3), value: state.currentLyricIndex)
            } else if state.lyricsStatus == "searching" {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Searching lyrics...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(height: 28)
            } else if state.lyricsStatus == "not_found" {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                    Text("No lyrics found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button(action: { state.retryLyrics() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                .frame(height: 28)
            }
            
            // 4. Progress Bar
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
            
            // 5. Playback Controls
            HStack(spacing: 0) {
                Button(action: { state.post("shuffle") }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 16))
                        .foregroundColor(state.isShuffled ? .accentColor : .secondary)
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
                
                Button(action: { state.post("prev") }) { 
                    Image(systemName: "backward.fill").font(.title2) 
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
                .keyboardShortcut(.leftArrow, modifiers: [])
                
                Button(action: { state.post("playpause") }) { 
                    Image(systemName: state.status.paused ? "play.circle.fill" : "pause.circle.fill")
                        .font(.system(size: 40)) 
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
                .keyboardShortcut(.space, modifiers: [])
                
                Button(action: { state.post("next") }) { 
                    Image(systemName: "forward.fill").font(.title2) 
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
                .keyboardShortcut(.rightArrow, modifiers: [])
                
                Button(action: { state.post("repeat") }) {
                    Image(systemName: state.repeatMode == .one ? "repeat.1" : "repeat")
                        .font(.system(size: 16))
                        .foregroundColor(state.repeatMode != .off ? .accentColor : .secondary)
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
                
                Button(action: { toggleCurrentFavorite() }) {
                    Image(systemName: isCurrentFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(isCurrentFavorite ? .pink : .secondary)
                }.buttonStyle(.plain).frame(maxWidth: .infinity)
            }
            
            // 6. Volume
            HStack {
                let vol = state.status.volume
                Image(systemName: vol == 0 ? "speaker.slash.fill" : vol < 0.4 ? "speaker.fill" : vol < 0.7 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")
                    .foregroundColor(.secondary).font(.caption2)
                    .frame(width: 16)
                    
                CustomSlider(value: Binding(get: {
                    state.status.volume
                }, set: { val in
                    state.status.volume = val
                    state.setVolume(val)
                }), total: 1.0)
            }
            .padding(.horizontal, 10)
            
            // Library Toggle
            Divider()
            
            Button(action: { withAnimation { showLibrary.toggle() } }) {
                HStack {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 12))
                    Text("Library")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Image(systemName: showLibrary ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundColor(showLibrary ? .accentColor : .secondary)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)
            
            if showLibrary {
                LibraryView(state: state, library: state.musicLibrary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // 7. Queue Section
            VStack(spacing: 8) {
                Divider()
                HStack {
                    Text("Queue").font(.caption).bold().foregroundColor(.secondary)
                    Spacer()
                    if !state.tracks.isEmpty {
                        Text("\(state.tracks.count)").font(.caption2).padding(.horizontal, 6).padding(.vertical, 2).background(Color.secondary.opacity(0.2)).cornerRadius(10)
                    }
                }
                
                if state.tracks.isEmpty {
                    Text("Add a song to get started")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(0..<state.tracks.count, id: \.self) { i in
                                let track = state.tracks[i]
                                let isCurrent = i == state.currentTrackIndex
                                HStack {
                                    Text("\(i + 1)").font(.caption2.monospacedDigit()).foregroundColor(isCurrent ? .accentColor : .secondary).frame(width: 20, alignment: .leading)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(track.title).font(.system(size: 12, weight: isCurrent ? .semibold : .regular)).lineLimit(1).foregroundColor(isCurrent ? .accentColor : .primary)
                                        if !track.artist.isEmpty {
                                            Text(track.artist).font(.system(size: 10)).lineLimit(1).foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button(action: { state.removeTrack(at: i) }) {
                                        Image(systemName: "xmark").font(.caption).foregroundColor(.secondary)
                                    }.buttonStyle(.plain).padding(4)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isCurrent ? Color.accentColor.opacity(0.1) : Color.clear)
                                .cornerRadius(6)
                                .onTapGesture {
                                    if !isCurrent {
                                        state.currentTrackIndex = i
                                        state.playCurrentTrack()
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(VisualEffectView().edgesIgnoringSafeArea(.all))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: state.tracks.count)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url {
                        DispatchQueue.main.async {
                            state.addLocalTrack(url: url)
                        }
                    }
                }
            }
            return true
        }
    }
    
    private func submitSearch() {
        if !searchQuery.isEmpty {
            state.addTrack(query: searchQuery)
            searchQuery = ""
            isSearchFocused = false
        }
    }
    
    private var isCurrentFavorite: Bool {
        guard state.currentTrackIndex >= 0 && state.currentTrackIndex < state.tracks.count else { return false }
        let track = state.tracks[state.currentTrackIndex]
        let id = track.videoId.isEmpty ? track.url : track.videoId
        return state.musicLibrary.isFavorite(id: id)
    }
    
    private func toggleCurrentFavorite() {
        guard state.currentTrackIndex >= 0 && state.currentTrackIndex < state.tracks.count else { return }
        let track = state.tracks[state.currentTrackIndex]
        let saved = SavedTrack.from(track: track)
        state.musicLibrary.toggleFavorite(saved)
    }
}
