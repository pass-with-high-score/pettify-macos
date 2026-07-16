import SwiftUI

struct LibraryView: View {
    @ObservedObject var state: AppState
    @ObservedObject var library: MusicLibraryService
    @State private var selectedTab: String = "history"
    @State private var isScanning: Bool = false
    @State private var searchText: String = ""

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: DS.Spacing.lg)]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Title
            Text("Your Library")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            // Tabs + filter
            HStack(spacing: DS.Spacing.sm) {
                tabPill(title: "Recent", tab: "history", count: library.history.count)
                tabPill(title: "Favorites", tab: "favorites", count: library.favorites.count)
                tabPill(title: "Local", tab: "local", count: library.localFiles.count)

                Spacer()

                if selectedTab == "local" {
                    scanButton
                }

                filterField
            }

            // Content
            switch selectedTab {
            case "history":
                grid(tracks: library.history, emptyMessage: "No recently played tracks", emptyIcon: "clock")
            case "favorites":
                grid(tracks: library.favorites, emptyMessage: "No favorite tracks yet", emptyIcon: "heart")
            case "local":
                grid(tracks: library.localFiles, emptyMessage: "Tap 'Scan' to find audio files in ~/Music and ~/Downloads", emptyIcon: "folder")
            default:
                EmptyView()
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Tab pill
    private func tabPill(title: String, tab: String, count: Int) -> some View {
        let isSelected = selectedTab == tab
        return Button(action: { selectedTab = tab }) {
            HStack(spacing: DS.Spacing.xs) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .semibold))
                        .opacity(0.7)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white : DS.Spotify.cardHover)
            .foregroundColor(isSelected ? .black : .white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var filterField: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(DS.Spotify.textSecondary)
            TextField("Filter", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 120)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(DS.Spotify.textSecondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 6)
        .background(DS.Spotify.field)
        .clipShape(Capsule())
    }

    private var scanButton: some View {
        Button(action: {
            isScanning = true
            library.scanLocalMusic { isScanning = false }
        }) {
            HStack(spacing: DS.Spacing.xs) {
                if isScanning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                }
                Text(isScanning ? "Scanning…" : "Scan")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, 6)
            .background(DS.Spotify.green)
            .foregroundColor(.black)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isScanning)
    }

    // MARK: Grid
    private func grid(tracks: [SavedTrack], emptyMessage: String, emptyIcon: String) -> some View {
        let filtered = tracks.filter {
            searchText.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artist.localizedCaseInsensitiveContains(searchText)
        }
        return Group {
            if filtered.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Image(systemName: emptyIcon)
                        .font(.system(size: 40))
                        .foregroundColor(DS.Spotify.textTertiary)
                    Text(emptyMessage)
                        .font(.system(size: 14))
                        .foregroundColor(DS.Spotify.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, DS.Spacing.xxl)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: DS.Spacing.lg) {
                        ForEach(filtered) { track in
                            AlbumCard(
                                track: track,
                                isFavorite: library.isFavorite(id: track.id),
                                onPlay: { playFromLibrary(track: track) },
                                onToggleFavorite: { library.toggleFavorite(track) }
                            )
                        }
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func playFromLibrary(track: SavedTrack) {
        let trackInfo = TrackInfo(
            title: track.title,
            videoId: track.videoId,
            url: track.url,
            artist: track.artist,
            localThumbnailURL: track.thumbnailURL.isEmpty ? nil : track.thumbnailURL
        )
        state.tracks.append(trackInfo)
        state.currentTrackIndex = state.tracks.count - 1
        state.playCurrentTrack()
    }
}

// MARK: - AlbumCard
// Spotify-style album tile: cover art with a green play button that fades in on
// hover, title + artist below, and a heart shown on hover.
struct AlbumCard: View {
    let track: SavedTrack
    let isFavorite: Bool
    let onPlay: () -> Void
    let onToggleFavorite: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                ArtworkView(thumbnail: track.thumbnailURL, cornerRadius: DS.Radius.md)
                    .aspectRatio(1, contentMode: .fit)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

                SpotifyPlayButton(isPaused: true, size: 46, action: onPlay)
                    .padding(DS.Spacing.sm)
                    .opacity(isHovering ? 1 : 0)
                    .offset(y: isHovering ? 0 : 8)

                if isHovering || isFavorite {
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14))
                            .foregroundColor(isFavorite ? DS.Spotify.green : .white)
                            .padding(6)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(DS.Spacing.sm)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }

            Text(track.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Text(track.artist.isEmpty ? (track.isLocal ? "Local file" : "Unknown artist") : track.artist)
                .font(.system(size: 12))
                .foregroundColor(DS.Spotify.textSecondary)
                .lineLimit(1)
        }
        .padding(DS.Spacing.md)
        .background(isHovering ? DS.Spotify.cardHover : DS.Spotify.card)
        .cornerRadius(DS.Radius.md)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.18)) { isHovering = hovering }
        }
        .onTapGesture(count: 2) { onPlay() }
    }
}
