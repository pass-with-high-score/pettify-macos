# Petify (macOS Menubar Edition)

A beautifully designed, feature-rich macOS menubar audio player built with SwiftUI. Originally a Go TUI application, it has now been fully reimagined as a native macOS application.

## Features

- **Menubar Player**: Quick access to your music right from the macOS menubar.
- **YouTube Support**: Paste any YouTube link (or search query) to instantly stream audio, powered by `yt-dlp`.
- **Local Audio**: Drag and drop local audio files (`.mp3`, `.wav`, etc.) directly into the app.
- **Floating Lyrics**: A highly customizable floating window for lyrics that stays on top.
  - **Animations**: Choose from Slide, Scale, Blur, 3D Flip, Random per Song, or Random per Line.
  - **Styles**: Customize font styles (Rounded, Serif, Monospaced) and colors (Dynamic, Pink, Yellow, White).
- **Desktop Pet (Neko)**: An animated pet that follows your mouse or roams the screen edge. Choose from dozens of custom skins!
- **Audio Visualizer**: Real-time visualizer built right into the UI.
- **Spinning Vinyl Art**: Dynamic album art that spins while playing, complete with interactive Easter eggs (e.g. reverse spin, DJ scratch, hyper speed).

## Requirements

- macOS 12.0+
- Xcode Command Line Tools or Xcode

## Installation & Build

1. Clone the repository:
   ```bash
   git clone https://github.com/pass-with-high-score/audio-cli.git
   cd audio-cli
   ```

2. Open the Swift package and build:
   ```bash
   cd Petify
   swift build -c release
   ```
   Or open `Petify/Package.swift` in Xcode and click Run.

## Usage

- Click the menubar icon to open the player.
- Paste a YouTube URL or type a search query in the text field to play a song.
- Drag & Drop an audio file into the popover to play locally.
- Access **Settings** (gear icon) to tweak lyrics animations, desktop pet behaviors, and audio quality.

## License

MIT
