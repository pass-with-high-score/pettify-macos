package player

import (
	"bytes"
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
	var tracks []Track
	var filtered []int

	if strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://") {
		if _, err := exec.LookPath("yt-dlp"); err != nil {
			fmt.Println("❌ Error: yt-dlp is not installed or not in PATH.")
			fmt.Println("Please install it from: https://github.com/yt-dlp/yt-dlp#installation")
			os.Exit(1)
		}
		
		fmt.Println("⏳ Fetching playlist info... Please wait.")
		var stdout, stderr bytes.Buffer
		cmd := exec.Command("yt-dlp", "--flat-playlist", "--print", "%(title)s|%(url)s|%(uploader)s", path)
		cmd.Stdout = &stdout
		cmd.Stderr = &stderr
		err := cmd.Run()
		if err != nil {
			log.Fatalf("\n❌ yt-dlp failed:\n%s\nError: %v\n\n💡 Tip: If YouTube says 'Sign in to confirm you’re not a bot' or 'HTTP 429', try updating yt-dlp (e.g., 'brew upgrade yt-dlp' or 'pip install -U yt-dlp') or use a different network.", stderr.String(), err)
		}
		
		lines := strings.Split(stdout.String(), "\n")
		for _, line := range lines {
			if strings.TrimSpace(line) == "" {
				continue
			}
			parts := strings.Split(line, "|")
			if len(parts) >= 2 {
				title := parts[0]
				url := parts[1]
				if !strings.HasPrefix(url, "http") {
					url = "https://youtu.be/" + url
				}
				artist := ""
				if len(parts) >= 3 {
					artist = parts[2]
				}
				tracks = append(tracks, Track{
					Path:   url,
					Title:  title,
					Artist: artist,
				})
				filtered = append(filtered, len(tracks)-1)
			}
		}
	} else {
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
	}

	if len(tracks) == 0 {
		fmt.Println("No tracks found.")
		os.Exit(1)
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
		loading:        true,
		config:         loadConfig(),
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
