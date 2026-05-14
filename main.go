package main

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/dhowden/tag"
	"github.com/faiface/beep"
	"github.com/faiface/beep/effects"
	"github.com/faiface/beep/flac"
	"github.com/faiface/beep/mp3"
	"github.com/faiface/beep/speaker"
	"github.com/faiface/beep/vorbis"
	"github.com/faiface/beep/wav"
)

// --- Simple Styles ---

var (
	subtle = lipgloss.AdaptiveColor{Light: "#D9D9D9", Dark: "#383838"}
	accent = lipgloss.Color("#7D56F4")

	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Padding(0, 1).
			Foreground(lipgloss.Color("#FAFAFA")).
			Background(accent).
			MarginBottom(1)

	nowPlayingStyle = lipgloss.NewStyle().Bold(true)
	dimStyle        = lipgloss.NewStyle().Foreground(subtle)
	selectedStyle   = lipgloss.NewStyle().Foreground(accent).Bold(true)
	
	statusStyle = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder(), false, false, false, true).
			BorderForeground(accent).
			PaddingLeft(2).
			MarginTop(1)

	helpStyle = lipgloss.NewStyle().
			Foreground(subtle).
			MarginTop(1)
)

// --- Model ---

type Track struct {
	Path   string
	Title  string
	Artist string
}

type model struct {
	tracks         []Track
	filteredTracks []int // Indices of tracks matching search
	currentIndex   int   // Index in filteredTracks
	streamer       beep.StreamSeekCloser
	format         beep.Format
	ctrl           *beep.Ctrl
	volume         *effects.Volume
	progress       progress.Model
	searchBar      textinput.Model
	searching      bool
	quitting       bool
	loop           bool
	shuffle        bool
	err            error
	initialized    bool
	width          int
	pointA         int
	pointB         int
	abActive       bool
}

type tickMsg time.Time
type loadMsg struct {
	streamer beep.StreamSeekCloser
	format   beep.Format
	err      error
}

func main() {
	if len(os.Args) < 2 {
		fmt.Println("Usage: go-play-audio <file or directory> [-shuffle] [-loop]")
		os.Exit(1)
	}

	path := os.Args[1]
	shuffleFlag := false
	loopFlag := false

	for _, arg := range os.Args[2:] {
		if arg == "-shuffle" {
			shuffleFlag = true
		}
		if arg == "-loop" {
			loopFlag = true
		}
	}

	var files []string
	info, err := os.Stat(path)
	if err != nil {
		log.Fatal(err)
	}

	supportedExts := map[string]bool{
		".mp3":  true,
		".wav":  true,
		".ogg":  true,
		".flac": true,
	}

	if info.IsDir() {
		entries, err := os.ReadDir(path)
		if err != nil {
			log.Fatal(err)
		}
		for _, entry := range entries {
			if !entry.IsDir() {
				ext := strings.ToLower(filepath.Ext(entry.Name()))
				if supportedExts[ext] {
					files = append(files, filepath.Join(path, entry.Name()))
				}
			}
		}
	} else {
		files = append(files, path)
	}

	if len(files) == 0 {
		fmt.Println("No supported audio files found (.mp3, .wav, .ogg, .flac).")
		os.Exit(1)
	}

	rand.Seed(time.Now().UnixNano())
	if shuffleFlag {
		rand.Shuffle(len(files), func(i, j int) {
			files[i], files[j] = files[j], files[i]
		})
	}

	// Parse tracks
	var tracks []Track
	var filtered []int
	for i, f := range files {
		track := Track{Path: f, Title: filepath.Base(f)}
		file, err := os.Open(f)
		if err == nil {
			m, err := tag.ReadFrom(file)
			if err == nil {
				if m.Title() != "" {
					track.Title = m.Title()
				}
				track.Artist = m.Artist()
			}
			file.Close()
		}
		tracks = append(tracks, track)
		filtered = append(filtered, i)
	}

	ti := textinput.New()
	ti.Placeholder = "Search songs..."
	ti.CharLimit = 32
	ti.Width = 20

	m := model{
		tracks:         tracks,
		filteredTracks: filtered,
		progress:       progress.New(progress.WithSolidFill("#7D56F4")),
		searchBar:      ti,
		loop:           loopFlag,
		shuffle:        shuffleFlag,
	}

	if _, err := tea.NewProgram(m).Run(); err != nil {
		fmt.Printf("Error running program: %v", err)
		os.Exit(1)
	}
}

func (m model) Init() tea.Cmd {
	return tea.Batch(tick(), m.loadSongCmd(m.currentIndex))
}

func (m model) loadSongCmd(index int) tea.Cmd {
	return func() tea.Msg {
		if index < 0 || index >= len(m.filteredTracks) {
			return loadMsg{err: fmt.Errorf("invalid track index")}
		}
		track := m.tracks[m.filteredTracks[index]]
		f, err := os.Open(track.Path)
		if err != nil {
			return loadMsg{err: err}
		}

		var streamer beep.StreamSeekCloser
		var format beep.Format
		ext := strings.ToLower(filepath.Ext(track.Path))

		switch ext {
		case ".mp3":
			streamer, format, err = mp3.Decode(f)
		case ".wav":
			streamer, format, err = wav.Decode(f)
		case ".ogg":
			streamer, format, err = vorbis.Decode(f)
		case ".flac":
			streamer, format, err = flac.Decode(f)
		default:
			err = fmt.Errorf("unsupported format: %s", ext)
		}

		if err != nil {
			return loadMsg{err: err}
		}

		return loadMsg{streamer: streamer, format: format}
	}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if m.searching {
		switch msg := msg.(type) {
		case tea.KeyMsg:
			switch msg.String() {
			case "enter", "esc":
				m.searching = false
				m.searchBar.Blur()
				return m, nil
			}
		}
		var cmd tea.Cmd
		m.searchBar, cmd = m.searchBar.Update(msg)
		
		// Re-filter
		query := strings.ToLower(m.searchBar.Value())
		var filtered []int
		for i, t := range m.tracks {
			if strings.Contains(strings.ToLower(t.Title), query) || strings.Contains(strings.ToLower(t.Artist), query) {
				filtered = append(filtered, i)
			}
		}
		m.filteredTracks = filtered
		// Reset index if out of bounds
		if m.currentIndex >= len(m.filteredTracks) {
			m.currentIndex = 0
		}
		
		return m, cmd
	}

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.progress.Width = msg.Width - 10
		return m, nil

	case loadMsg:
		if msg.err != nil {
			m.err = msg.err
			return m, tea.Quit
		}

		if m.streamer != nil {
			m.streamer.Close()
		}

		m.streamer = msg.streamer
		m.format = msg.format
		m.abActive = false // Reset AB on new song
		
		m.ctrl = &beep.Ctrl{Streamer: m.streamer, Paused: false}
		m.volume = &effects.Volume{Streamer: m.ctrl, Base: 2, Volume: 0, Silent: false}

		if !m.initialized {
			speaker.Init(m.format.SampleRate, m.format.SampleRate.N(time.Second/10))
			m.initialized = true
		}

		speaker.Clear()
		speaker.Play(m.volume)
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		case "/":
			m.searching = true
			m.searchBar.Focus()
			return m, nil
		case " ":
			if m.ctrl != nil {
				speaker.Lock()
				m.ctrl.Paused = !m.ctrl.Paused
				speaker.Unlock()
			}
		case "n", "right":
			return m.nextSong()
		case "p", "left":
			return m.prevSong()
		case "l":
			m.loop = !m.loop
		case "s":
			m.shuffle = !m.shuffle
		case "up":
			if m.volume != nil {
				speaker.Lock()
				m.volume.Volume += 0.1
				speaker.Unlock()
			}
		case "down":
			if m.volume != nil {
				speaker.Lock()
				m.volume.Volume -= 0.1
				speaker.Unlock()
			}
		case "j": // Back 10s
			if m.streamer != nil {
				speaker.Lock()
				newPos := m.streamer.Position() - m.format.SampleRate.N(time.Second*10)
				if newPos < 0 {
					newPos = 0
				}
				m.streamer.Seek(newPos)
				speaker.Unlock()
			}
		case "k": // Forward 10s
			if m.streamer != nil {
				speaker.Lock()
				newPos := m.streamer.Position() + m.format.SampleRate.N(time.Second*10)
				if newPos >= m.streamer.Len() {
				} else {
					m.streamer.Seek(newPos)
				}
				speaker.Unlock()
			}
		case "[": // Mark A
			if m.streamer != nil {
				m.pointA = m.streamer.Position()
				m.abActive = false // Wait for B
			}
		case "]": // Mark B
			if m.streamer != nil {
				pos := m.streamer.Position()
				if pos > m.pointA {
					m.pointB = pos
					m.abActive = true
				}
			}
		case "\\": // Clear AB
			m.abActive = false
		}

	case tickMsg:
		if m.quitting {
			return m, nil
		}
		if m.abActive && m.streamer != nil {
			if m.streamer.Position() >= m.pointB {
				speaker.Lock()
				m.streamer.Seek(m.pointA)
				speaker.Unlock()
			}
		}
		if m.streamer != nil && m.streamer.Position() >= m.streamer.Len() {
			return m.nextSong()
		}
		return m, tick()

	case progress.FrameMsg:
		progressModel, cmd := m.progress.Update(msg)
		m.progress = progressModel.(progress.Model)
		return m, cmd
	}

	return m, nil
}

func (m model) nextSong() (model, tea.Cmd) {
	if len(m.filteredTracks) == 0 {
		return m, nil
	}
	m.currentIndex++
	if m.currentIndex >= len(m.filteredTracks) {
		if m.loop {
			m.currentIndex = 0
		} else {
			m.quitting = true
			return m, tea.Quit
		}
	}
	return m, m.loadSongCmd(m.currentIndex)
}

func (m model) prevSong() (model, tea.Cmd) {
	if len(m.filteredTracks) == 0 {
		return m, nil
	}
	m.currentIndex--
	if m.currentIndex < 0 {
		m.currentIndex = len(m.filteredTracks) - 1
	}
	return m, m.loadSongCmd(m.currentIndex)
}

func (m model) View() string {
	if m.err != nil {
		return fmt.Sprintf("\n  Error: %v\n", m.err)
	}
	if m.quitting {
		return "\n  Playlist finished. Goodbye!\n"
	}

	var percent float64
	var elapsed, total time.Duration
	if m.streamer != nil {
		pos := m.streamer.Position()
		len := m.streamer.Len()
		percent = float64(pos) / float64(len)
		elapsed = m.format.SampleRate.D(pos).Round(time.Second)
		total = m.format.SampleRate.D(len).Round(time.Second)
	}

	status := "PLAYING"
	if m.ctrl != nil && m.ctrl.Paused {
		status = "PAUSED "
	}

	// Build View
	s := "\n" + titleStyle.Render("AUDIO PLAYER") + "\n\n"
	
	if len(m.filteredTracks) > 0 {
		track := m.tracks[m.filteredTracks[m.currentIndex]]
		displayTitle := track.Title
		if track.Artist != "" {
			displayTitle = fmt.Sprintf("%s - %s", track.Artist, track.Title)
		}
		s += nowPlayingStyle.Render("Now Playing: ") + displayTitle + "\n"
		s += m.progress.ViewAs(percent) + "\n"
		
		modeInfo := ""
		if m.loop { modeInfo += " [Loop] " }
		if m.shuffle { modeInfo += " [Shuffle] " }
		
		volInfo := ""
		if m.volume != nil {
			volInfo = fmt.Sprintf(" Vol: %.1f", m.volume.Volume)
		}

		statusInfo := fmt.Sprintf("%s  %s / %s %s %s", status, elapsed, total, modeInfo, volInfo)
		if m.abActive {
			aTime := m.format.SampleRate.D(m.pointA).Round(time.Second)
			bTime := m.format.SampleRate.D(m.pointB).Round(time.Second)
			statusInfo += fmt.Sprintf(" [A-B: %s-%s]", aTime, bTime)
		}
		s += statusStyle.Render(statusInfo) + "\n"	} else {
		s += "No tracks found matching search.\n\n"
	}

	if m.searching {
		s += "\n Search: " + m.searchBar.View() + "\n"
	} else {
		s += "\n" + dimStyle.Render("Playlist:") + "\n"
		start := m.currentIndex - 2
		if start < 0 { start = 0 }
		end := start + 5
		if end > len(m.filteredTracks) { end = len(m.filteredTracks) }

		for i := start; i < end; i++ {
			t := m.tracks[m.filteredTracks[i]]
			tName := t.Title
			if t.Artist != "" {
				tName = fmt.Sprintf("%s - %s", t.Artist, t.Title)
			}
			if i == m.currentIndex {
				s += selectedStyle.Render(fmt.Sprintf("  ▸ %s", tName)) + "\n"
			} else {
				s += dimStyle.Render(fmt.Sprintf("    %s", tName)) + "\n"
			}
		}
	}

	s += helpStyle.Render("Space: Pause • N/P: Next/Prev • J/K: Seek • Up/Down: Vol • []: A-B • \\: Clear • /: Search • Q: Quit") + "\n"

	return s
}

func tick() tea.Cmd {
	return tea.Tick(time.Millisecond*100, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}
