# Audio CLI

A clean, professional Terminal User Interface (TUI) music player for macOS written in Go.

## Features

- **Multi-format Support**: Plays `.mp3`, `.wav`, `.ogg`, and `.flac`.
- **Clean TUI**: Built with [Bubble Tea](https://github.com/charmbracelet/bubbletea) and [Lip Gloss](https://github.com/charmbracelet/lipgloss).
- **A-B Repeat**: Mark start (`[`) and end (`]`) points to loop a specific segment.
- **Metadata Support**: Displays Artist and Title from ID3 tags.
- **Playlist Management**: Support for folder playback, shuffle, and loop modes.
- **Search**: Instant filtering of your playlist with `/`.
- **Advanced Controls**:
    - `Space`: Play/Pause
    - `N` / `P`: Next/Previous track
    - `Left` / `Right`: Seek backward/forward 10s
    - `Up` / `Down`: Volume control
    - `[` / `]`: Set A-B Repeat points
    - `\`: Clear A-B Repeat
    - `/`: Search playlist
    - `L` / `S`: Toggle Loop/Shuffle
    - `Q`: Quit

## Installation

### Prerequisites

- Go 1.16+
- macOS (uses `AudioToolbox.framework`)
- Xcode Command Line Tools (`xcode-select --install`)

### Build from source

```bash
git clone https://github.com/pass-with-high-score/audio-cli.git
cd audio-cli
go build -o audio-cli main.go
```

## Usage

```bash
./audio-cli <path-to-folder-or-file> [-shuffle] [-loop]
```

## License

MIT
