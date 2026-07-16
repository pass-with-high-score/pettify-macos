import SwiftUI

// MARK: - MainWindowView
// Root content of the app window — a Spotify-style dark shell: black sidebar
// (navigation + search) beside a #121212 content panel, with a persistent
// player bar pinned to the bottom. Always dark, green accent.
// Uses HSplitView (not NavigationSplitView) to keep macOS 12 compatibility.
struct MainWindowView: View {
    @ObservedObject var state: AppState

    enum Section: String, CaseIterable {
        case nowPlaying, library, queue

        var title: String {
            switch self {
            case .nowPlaying: return "Now Playing"
            case .library: return "Library"
            case .queue: return "Queue"
            }
        }
        var icon: String {
            switch self {
            case .nowPlaying: return "play.square.fill"
            case .library: return "square.grid.2x2.fill"
            case .queue: return "list.bullet"
            }
        }
    }

    @State private var selection: Section = .nowPlaying
    @State private var searchQuery: String = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 232)
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)

            PlayerBarView(state: state)
        }
        .background(DS.Spotify.base)
        .preferredColorScheme(.dark)
        .tint(DS.Spotify.green)
        .accentColor(DS.Spotify.green)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url {
                        DispatchQueue.main.async { state.addLocalTrack(url: url) }
                    }
                }
            }
            return true
        }
    }

    // MARK: Sidebar (black)
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Brand
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "music.note.house.fill")
                    .font(.system(size: 22))
                    .foregroundColor(DS.Spotify.green)
                Text("Petify")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.top, DS.Spacing.sm)

            searchBar

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ForEach(Section.allCases, id: \.self) { section in
                    navRow(section)
                }
            }

            Spacer()

            Rectangle().fill(DS.Spotify.separator).frame(height: 1)
            HStack {
                sidebarIconButton("gearshape.fill", help: "Settings") {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenSettings"), object: nil)
                }
                Spacer()
                sidebarIconButton("power", help: "Quit") {
                    NotificationCenter.default.post(name: NSNotification.Name("QuitApp"), object: nil)
                }
            }
            .padding(.horizontal, DS.Spacing.sm)
        }
        .padding(DS.Spacing.md)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(DS.Spotify.base)
    }

    private func navRow(_ section: Section) -> some View {
        let isSelected = selection == section
        return Button(action: { selection = section }) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: section.icon)
                    .font(.system(size: 18))
                    .frame(width: 24)
                Text(section.title)
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                if section == .queue && !state.tracks.isEmpty {
                    Text("\(state.tracks.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : DS.Spotify.textTertiary)
                }
            }
            .foregroundColor(isSelected ? .white : DS.Spotify.textSecondary)
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.md)
            .background(isSelected ? DS.Spotify.cardHover : Color.clear)
            .cornerRadius(DS.Radius.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sidebarIconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 15))
                .foregroundColor(DS.Spotify.textSecondary)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var searchBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "magnifyingglass").foregroundColor(DS.Spotify.textSecondary)
            TextField("Search or paste URL…", text: $searchQuery)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .focused($isSearchFocused)
                .onSubmit { submitSearch() }

            if !state.status.searchStatus.isEmpty {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(0.5)
                    .frame(width: 16, height: 16)
            } else if !searchQuery.isEmpty {
                Button(action: submitSearch) {
                    Image(systemName: "return").foregroundColor(DS.Spotify.green)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Spotify.field)
        .cornerRadius(DS.Radius.md)
    }

    // MARK: Detail (#121212)
    @ViewBuilder
    private var detail: some View {
        Group {
            switch selection {
            case .nowPlaying:
                NowPlayingView(state: state)
            case .library:
                LibraryView(state: state, library: state.musicLibrary)
            case .queue:
                QueueView(state: state)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Spotify.bg)
    }

    private func submitSearch() {
        guard !searchQuery.isEmpty else { return }
        state.addTrack(query: searchQuery)
        searchQuery = ""
        isSearchFocused = false
    }
}

// MARK: - QueueView
// Full-height queue list, Spotify dark rows.
struct QueueView: View {
    @ObservedObject var state: AppState
    @State private var hoverIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text("Queue")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white)

            if state.tracks.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(0..<state.tracks.count, id: \.self) { i in
                            row(index: i)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var emptyState: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundColor(DS.Spotify.textTertiary)
            Text("Add a song to get started")
                .font(.system(size: 15))
                .foregroundColor(DS.Spotify.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(index i: Int) -> some View {
        let track = state.tracks[i]
        let isCurrent = i == state.currentTrackIndex
        let isHover = hoverIndex == i
        return HStack(spacing: DS.Spacing.md) {
            ZStack {
                if isCurrent {
                    Image(systemName: "waveform")
                        .foregroundColor(DS.Spotify.green)
                        .font(.system(size: 14))
                } else {
                    Text("\(i + 1)")
                        .font(.system(size: 14).monospacedDigit())
                        .foregroundColor(DS.Spotify.textSecondary)
                }
            }
            .frame(width: 24, alignment: .center)

            ArtworkView(thumbnail: track.thumbnailURL, cornerRadius: DS.Radius.sm)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(isCurrent ? DS.Spotify.green : .white)
                if !track.artist.isEmpty {
                    Text(track.artist)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .foregroundColor(DS.Spotify.textSecondary)
                }
            }

            Spacer()

            if isHover {
                Button(action: { state.removeTrack(at: i) }) {
                    Image(systemName: "xmark").font(.system(size: 12)).foregroundColor(DS.Spotify.textSecondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(isHover ? DS.Spotify.cardHover : Color.clear)
        .cornerRadius(DS.Radius.sm)
        .contentShape(Rectangle())
        .onHover { hoverIndex = $0 ? i : (hoverIndex == i ? nil : hoverIndex) }
        .onTapGesture {
            if !isCurrent {
                state.currentTrackIndex = i
                state.playCurrentTrack()
            }
        }
    }
}
