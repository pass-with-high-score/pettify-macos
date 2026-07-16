import SwiftUI

// MARK: - NowPlayingView
// Spotify-style hero: an ambient gradient derived from the album's dominant
// color fades into the dark background, with a large album cover, big title,
// and a lyrics preview.
struct NowPlayingView: View {
    @ObservedObject var state: AppState

    var body: some View {
        GeometryReader { geo in
            let artSize = min(geo.size.width * 0.45, geo.size.height * 0.5, 360)

            ZStack(alignment: .top) {
                // Ambient gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        (state.dominantColor == .white ? DS.Spotify.elevated : state.dominantColor).opacity(0.55),
                        DS.Spotify.bg
                    ]),
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: state.dominantColor)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.xl) {
                        Spacer(minLength: DS.Spacing.xxl)

                        artwork(size: max(180, artSize))

                        trackInfo

                        lyricsPreview

                        Spacer(minLength: DS.Spacing.xl)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                    .padding(DS.Spacing.xl)
                }
            }
        }
    }

    // MARK: Artwork (with search-status overlay)
    private func artwork(size: CGFloat) -> some View {
        ZStack {
            ArtworkView(thumbnail: state.status.thumbnail, cornerRadius: DS.Radius.md)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 16)

            if !state.status.searchStatus.isEmpty {
                VStack(spacing: DS.Spacing.sm) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(state.status.searchStatus)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.md)
                }
                .frame(width: size, height: size)
                .background(Color.black.opacity(0.6))
                .cornerRadius(DS.Radius.md)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: state.status.searchStatus)
    }

    // MARK: Title / artist / download
    private var trackInfo: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text(state.status.title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !state.status.artist.isEmpty {
                Text(state.status.artist)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DS.Spotify.textSecondary)
                    .lineLimit(1)
            }

            if canDownloadCurrent {
                Button(action: { state.saveCurrentTrackOffline() }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.down.circle")
                        Text("Download for offline")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, 6)
                    .overlay(
                        Capsule().stroke(DS.Spotify.textSecondary, lineWidth: 1)
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, DS.Spacing.xs)
                .help("Download for offline playback")
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: Lyrics preview
    @ViewBuilder
    private var lyricsPreview: some View {
        if !state.lyrics.isEmpty {
            VStack(spacing: DS.Spacing.sm) {
                if state.currentLyricIndex >= 0 && state.currentLyricIndex < state.lyrics.count {
                    Text(state.lyrics[state.currentLyricIndex].text)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .id(state.lyrics[state.currentLyricIndex].id)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("♪").font(.system(size: 22)).foregroundColor(DS.Spotify.textSecondary)
                }

                if state.currentLyricIndex + 1 < state.lyrics.count {
                    Text(state.lyrics[state.currentLyricIndex + 1].text)
                        .font(.system(size: 16))
                        .foregroundColor(DS.Spotify.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: 560)
            .padding(.top, DS.Spacing.sm)
            .animation(.easeInOut(duration: 0.3), value: state.currentLyricIndex)
        } else if state.lyricsStatus == "searching" {
            HStack(spacing: DS.Spacing.sm) {
                ProgressView().controlSize(.small)
                Text("Searching lyrics…")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Spotify.textSecondary)
            }
        } else if state.lyricsStatus == "not_found" {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "music.note").foregroundColor(DS.Spotify.textSecondary)
                Text("No lyrics found")
                    .font(.system(size: 14))
                    .foregroundColor(DS.Spotify.textSecondary)
                Button(action: { state.retryLyrics() }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(DS.Spotify.green)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var canDownloadCurrent: Bool {
        state.currentTrackIndex >= 0
            && state.currentTrackIndex < state.tracks.count
            && !state.tracks[state.currentTrackIndex].url.hasPrefix("file://")
    }
}
