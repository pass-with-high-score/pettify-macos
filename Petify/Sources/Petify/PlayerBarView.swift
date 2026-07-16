import SwiftUI

// MARK: - ArtworkView
// Reusable album-art renderer: handles local file:// images, remote AsyncImage,
// and an empty placeholder. Shared by the player bar, Now Playing and library.
struct ArtworkView: View {
    let thumbnail: String
    var cornerRadius: CGFloat = DS.Radius.md

    var body: some View {
        Group {
            if thumbnail.isEmpty {
                placeholder
            } else if thumbnail.hasPrefix("file://"),
                      let url = URL(string: thumbnail),
                      let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AsyncImage(url: URL(string: thumbnail)) { phase in
                    if let image = phase.image {
                        image.resizable().aspectRatio(contentMode: .fill)
                    } else {
                        placeholder
                    }
                }
            }
        }
        .clipped()
        .cornerRadius(cornerRadius)
    }

    private var placeholder: some View {
        ZStack {
            DS.Spotify.elevated
            Image(systemName: "music.note")
                .font(.system(size: 22))
                .foregroundColor(DS.Spotify.textTertiary)
        }
    }
}

// MARK: - PlayerBarView
// Persistent Spotify-style transport bar pinned to the bottom of the window.
struct PlayerBarView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(DS.Spotify.separator).frame(height: 1)
            HStack(spacing: DS.Spacing.lg) {
                nowPlayingInfo
                    .frame(minWidth: 180, maxWidth: 300, alignment: .leading)

                transportAndProgress
                    .frame(maxWidth: .infinity)

                rightControls
                    .frame(minWidth: 180, maxWidth: 240, alignment: .trailing)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
        }
        .background(DS.Spotify.card)
    }

    // MARK: Left — track info
    private var nowPlayingInfo: some View {
        HStack(spacing: DS.Spacing.md) {
            ArtworkView(thumbnail: state.status.thumbnail, cornerRadius: DS.Radius.sm)
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(state.status.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                if !state.status.artist.isEmpty {
                    Text(state.status.artist)
                        .font(.system(size: 12))
                        .foregroundColor(DS.Spotify.textSecondary)
                        .lineLimit(1)
                }
            }

            Button(action: { toggleCurrentFavorite() }) {
                Image(systemName: isCurrentFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 15))
                    .foregroundColor(isCurrentFavorite ? DS.Spotify.green : DS.Spotify.textSecondary)
            }.buttonStyle(.plain).help("Favorite")
        }
    }

    // MARK: Center — transport + scrubber
    private var transportAndProgress: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xl) {
                Button(action: { state.post("shuffle") }) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 15))
                        .foregroundColor(state.isShuffled ? DS.Spotify.green : DS.Spotify.textSecondary)
                }.buttonStyle(.plain)

                Button(action: { state.post("prev") }) {
                    Image(systemName: "backward.fill").font(.system(size: 16)).foregroundColor(.white)
                }.buttonStyle(.plain)
                .keyboardShortcut(.leftArrow, modifiers: [])

                // White circular play/pause (Spotify bottom-bar style)
                Button(action: { state.post("playpause") }) {
                    ZStack {
                        Circle().fill(Color.white).frame(width: 38, height: 38)
                        Image(systemName: state.status.paused ? "play.fill" : "pause.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.black)
                            .offset(x: state.status.paused ? 1 : 0)
                    }
                }.buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                Button(action: { state.post("next") }) {
                    Image(systemName: "forward.fill").font(.system(size: 16)).foregroundColor(.white)
                }.buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button(action: { state.post("repeat") }) {
                    Image(systemName: state.repeatMode == .one ? "repeat.1" : "repeat")
                        .font(.system(size: 15))
                        .foregroundColor(state.repeatMode != .off ? DS.Spotify.green : DS.Spotify.textSecondary)
                }.buttonStyle(.plain)
            }

            HStack(spacing: DS.Spacing.sm) {
                Text(state.formatTime(state.status.position))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(DS.Spotify.textSecondary)

                CustomSlider(value: Binding(get: {
                    state.status.position
                }, set: { val in
                    state.status.position = val
                    state.seek(to: val)
                }), total: max(0.1, state.status.duration), tint: DS.Spotify.green)

                Text(state.formatTime(state.status.duration))
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(DS.Spotify.textSecondary)
            }
            .frame(maxWidth: 560)
        }
    }

    // MARK: Right — karaoke + volume
    private var rightControls: some View {
        HStack(spacing: DS.Spacing.md) {
            Button(action: {
                NotificationCenter.default.post(name: NSNotification.Name("OpenKaraoke"), object: nil)
            }) {
                Image(systemName: "music.mic")
                    .font(.system(size: 15))
                    .foregroundColor(DS.Spotify.textSecondary)
            }.buttonStyle(.plain).help("Karaoke Mode")

            HStack(spacing: DS.Spacing.xs) {
                let vol = state.status.volume
                Image(systemName: vol == 0 ? "speaker.slash.fill" : vol < 0.4 ? "speaker.fill" : vol < 0.7 ? "speaker.wave.2.fill" : "speaker.wave.3.fill")
                    .foregroundColor(DS.Spotify.textSecondary).font(.system(size: 12))
                    .frame(width: 18)

                CustomSlider(value: Binding(get: {
                    state.status.volume
                }, set: { val in
                    state.status.volume = val
                    state.setVolume(val)
                }), total: 1.0, tint: .white)
                .frame(width: 90)
            }
        }
    }

    // MARK: Favorite helpers
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
