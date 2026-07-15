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
                    
                    // Sync Delay Controls
                    if state.lyricsStatus == "found" && !state.lyrics.isEmpty {
                        HStack(spacing: 12) {
                            Text("Sync:")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            Button(action: { state.lyricsOffset -= 0.1 }) {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            
                            Text(String(format: "%.1fs", state.lyricsOffset))
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(width: 40, alignment: .center)
                                
                            Button(action: { state.lyricsOffset += 0.1 }) {
                                Image(systemName: "plus.circle.fill")
                            }
                            .buttonStyle(.plain)
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(20)
                    }
                    
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
                                    
                                    let nextTime = index + 1 < state.lyrics.count ? state.lyrics[index + 1].time : nil
                                    
                                    KaraokeLineView(
                                        line: line,
                                        nextLineTime: nextTime,
                                        isCurrent: isCurrent,
                                        isPast: isPast,
                                        state: state
                                    )
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
        // Hidden buttons for keyboard shortcuts within the window scope
        .background(
            ZStack {
                Button(action: { state.post("playpause") }) { EmptyView() }
                    .keyboardShortcut(.space, modifiers: [])
                Button(action: { state.post("prev") }) { EmptyView() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
                Button(action: { state.post("next") }) { EmptyView() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
            }
            .opacity(0)
        )
    }
}

struct KaraokeLineView: View {
    let line: LyricLine
    let nextLineTime: Double?
    let isCurrent: Bool
    let isPast: Bool
    @ObservedObject var state: AppState
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let currentTime = state.audioPlayer.currentTime - state.lyricsOffset
            let progress = computeProgress(currentTime: currentTime)
            
            Text(line.text)
                .font(.system(size: isCurrent ? 42 : 32, weight: .heavy, design: .rounded))
                .foregroundColor(isPast ? .white.opacity(0.3) : .white.opacity(0.5))
                .overlay(
                    GeometryReader { geo in
                        Text(line.text)
                            .font(.system(size: isCurrent ? 42 : 32, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .mask(
                                Rectangle()
                                    .frame(width: geo.size.width * progress)
                                    .offset(x: 0)
                                    .frame(width: geo.size.width, alignment: .leading)
                            )
                    }
                )
                .scaleEffect(isCurrent ? 1.05 : 1.0, anchor: .leading)
                .blur(radius: isCurrent ? 0 : (isPast ? 1 : 2))
                .animation(.interpolatingSpring(stiffness: 100, damping: 15), value: isCurrent)
        }
    }
    
    private func computeProgress(currentTime: Double) -> CGFloat {
        if isPast { return 1.0 }
        if !isCurrent { return 0.0 }
        
        let start = line.time
        let end = nextLineTime ?? (start + 5.0)
        let safeEnd = max(start + 0.5, end) // at least 0.5s duration
        
        if currentTime < start { return 0.0 }
        if currentTime > safeEnd { return 1.0 }
        
        // Linear interpolation
        let progress = (currentTime - start) / (safeEnd - start)
        return CGFloat(min(max(progress, 0.0), 1.0))
    }
}
