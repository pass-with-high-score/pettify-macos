package player

import (
	"fmt"
	"log"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/dhowden/tag"
)

func Run(path string, shuffleFlag bool, loopFlag bool) {
	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		if _, err := exec.LookPath("yt-dlp"); err != nil {
			fmt.Println("❌ Error: yt-dlp is not installed or not in PATH.")
			fmt.Println("Please install it from: https://github.com/yt-dlp/yt-dlp#installation")
			os.Exit(1)
		}
		tempDir, err := os.MkdirTemp("", "audio-cli-yt-*")
		if err != nil {
			log.Fatalf("Failed to create temp directory: %v", err)
		}
		fmt.Println("⏳ Downloading audio using yt-dlp... Please wait.")
		fmt.Printf("URL: %s\n\n", path)
		cmd := exec.Command("yt-dlp", "-x", "--audio-format", "mp3", "-o", filepath.Join(tempDir, "%(autonumber)03d_%(title)s.%(ext)s"), path)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			log.Fatalf("yt-dlp failed: %v", err)
		}
		fmt.Println("\n✅ Download complete! Starting player...")
		path = tempDir
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

func tick() tea.Cmd {
	return tea.Tick(time.Millisecond*100, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}
