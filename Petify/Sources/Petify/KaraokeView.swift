import SwiftUI

struct KaraokeView: View {
    @ObservedObject var state: AppState
    
    // Auto-scrolling state
    @State private var hoveredLyricIndex: Int? = nil
    
    var body: some View {
        ZStack {
            // Background
            if let artwork = state.currentArtwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 60, opaque: true)
                    .overlay(Color.black.opacity(0.4)) // Darken overlay
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // Content
            VStack {
                // Header (Now Playing Info)
                HStack(spacing: 16) {
                    if let artwork = state.currentArtwork {
                        Image(nsImage: artwork)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(state.status.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        
                        Text(state.status.artist)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Close button
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("CloseKaraoke"), object: nil)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .onHover { h in 
                        if h { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 40)
                
                Spacer()
                
                // Lyrics View
                if state.lyricsStatus == "found" && !state.lyrics.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 24) {
                                // Add empty space at top
                                Color.clear.frame(height: 150)
                                
                                ForEach(Array(state.lyrics.enumerated()), id: \.element.time) { index, line in
                                    let isCurrent = (index == state.currentLyricIndex)
                                    let isPast = (index < state.currentLyricIndex)
                                    
                                    Text(line.text)
                                        .font(.system(size: isCurrent ? 42 : 32, weight: .heavy, design: .rounded))
                                        .foregroundColor(isCurrent ? .white : .white.opacity(isPast ? 0.3 : 0.5))
                                        .scaleEffect(isCurrent ? 1.05 : 1.0, anchor: .leading)
                                        .blur(radius: isCurrent ? 0 : (isPast ? 1 : 2))
                                        .animation(.interpolatingSpring(stiffness: 100, damping: 15), value: isCurrent)
                                        .id(index)
                                        .contentShape(Rectangle())
                                        .onHover { hovered in
                                            hoveredLyricIndex = hovered ? index : nil
                                            if hovered { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                                        }
                                        .onTapGesture {
                                            // Click to seek
                                            state.audioPlayer.seek(to: line.time)
                                        }
                                        .overlay(
                                            hoveredLyricIndex == index && !isCurrent ?
                                            Color.white.opacity(0.1).cornerRadius(8) : nil
                                        )
                                }
                                
                                // Add empty space at bottom
                                Color.clear.frame(height: 200)
                            }
                            .padding(.horizontal, 40)
                        }
                        .onChange(of: state.currentLyricIndex) { newIndex in
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(newIndex, anchor: .center)
                            }
                        }
                        .onAppear {
                            proxy.scrollTo(state.currentLyricIndex, anchor: .center)
                        }
                    }
                } else if state.lyricsStatus == "searching" {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        Text("Looking for lyrics...")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.3))
                        Text("No synced lyrics found")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                
                Spacer()
                
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
