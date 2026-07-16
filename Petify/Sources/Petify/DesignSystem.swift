import SwiftUI

// MARK: - Color hex helper
extension Color {
    init(hex: UInt) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

// MARK: - Design System
// Central design tokens + reusable components so every surface (Main window,
// Settings, Karaoke) stays visually consistent. Compatible with macOS 12+.

enum DS {

    // MARK: Spotify-style dark palette (main window — always dark)
    enum Spotify {
        static let green = Color(hex: 0x1DB954)
        static let base = Color(hex: 0x000000)        // sidebar background
        static let bg = Color(hex: 0x121212)          // main content background
        static let card = Color(hex: 0x181818)        // card resting
        static let cardHover = Color(hex: 0x282828)   // card hover
        static let field = Color(hex: 0x242424)       // search / input field
        static let elevated = Color(hex: 0x2A2A2A)
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: 0xB3B3B3)
        static let textTertiary = Color(hex: 0x7A7A7A)
        static let separator = Color.white.opacity(0.08)
    }


    // MARK: Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Corner radius
    enum Radius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 14
    }

    // MARK: Colors
    enum Colors {
        static let accent = Color.accentColor
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        /// Subtle filled surface used for cards / fields.
        static let surface = Color.secondary.opacity(0.12)
        static let surfaceHover = Color.secondary.opacity(0.2)
        /// Tint applied to a selected / active element background.
        static let accentSoft = Color.accentColor.opacity(0.15)
    }

    // MARK: Fonts
    enum Fonts {
        static let largeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title = Font.system(size: 20, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 15, weight: .semibold)
        static let body = Font.system(size: 13)
        static let caption = Font.system(size: 11)
        static let mono = Font.system(size: 11, weight: .medium, design: .monospaced)
    }
}

// MARK: - Card modifier

extension View {
    /// Wraps content in a padded, rounded surface — the app's standard "card" look.
    func dsCard(padding: CGFloat = DS.Spacing.md,
                radius: CGFloat = DS.Radius.lg,
                fill: Color = DS.Colors.surface) -> some View {
        self
            .padding(padding)
            .background(fill)
            .cornerRadius(radius)
    }

    /// Adds a pointing-hand cursor on hover (used by clickable rows).
    func dsPointerOnHover() -> some View {
        self.onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - IconButton

/// A compact, plain icon button with a consistent hit target + tooltip.
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 14
    var color: Color = DS.Colors.textSecondary
    var help: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size))
                .foregroundColor(color)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - SectionHeader

/// Uppercased-style section label with an optional trailing count badge.
struct SectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(DS.Colors.textSecondary)
            Spacer()
            if let count = count, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 2)
                    .background(DS.Colors.surface)
                    .cornerRadius(10)
            }
        }
    }
}

// MARK: - SidebarItem (shared by Main window + Settings)

/// A single navigation row for a sidebar. Selected state fills with the accent color.
struct SidebarItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var count: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .frame(width: 20)
                    .foregroundColor(isSelected ? .white : DS.Colors.textPrimary)
                Text(title)
                    .foregroundColor(isSelected ? .white : DS.Colors.textPrimary)
                Spacer()
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(isSelected ? .white.opacity(0.9) : DS.Colors.textSecondary)
                }
            }
            .padding(.vertical, DS.Spacing.sm)
            .padding(.horizontal, DS.Spacing.md)
            .background(isSelected ? DS.Colors.accent : Color.clear)
            .cornerRadius(DS.Radius.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SpotifyPlayButton

/// Round green play/pause button with a black glyph — the signature Spotify accent control.
struct SpotifyPlayButton: View {
    var isPaused: Bool = true
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle().fill(DS.Spotify.green)
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: size * 0.42))
                    .foregroundColor(.black)
                    .offset(x: isPaused ? size * 0.03 : 0)
            }
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
