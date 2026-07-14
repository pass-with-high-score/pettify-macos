package player

import (
	"crypto/md5"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/faiface/beep"
	"github.com/faiface/beep/flac"
	"github.com/faiface/beep/mp3"
	"github.com/faiface/beep/speaker"
	"github.com/faiface/beep/vorbis"
	"github.com/faiface/beep/wav"
)

func (m model) loadSongCmd(index int) tea.Cmd {
	return func() tea.Msg {
		if index < 0 || index >= len(m.filteredTracks) {
			return loadMsg{err: fmt.Errorf("invalid track index")}
		}
		track := m.tracks[m.filteredTracks[index]]
		
		filePath := track.Path
		if strings.HasPrefix(filePath, "http://") || strings.HasPrefix(filePath, "https://") {
			tempDir := filepath.Join(os.TempDir(), "audio-cli-yt")
			os.MkdirAll(tempDir, 0755)
			
			hash := fmt.Sprintf("%x", md5.Sum([]byte(track.Path)))
			outFile := filepath.Join(tempDir, hash+".mp3")
			
			if _, err := os.Stat(outFile); os.IsNotExist(err) {
				cmd := exec.Command("yt-dlp", "-x", "--audio-format", "mp3", "-o", outFile, track.Path)
				if err := cmd.Run(); err != nil {
					return loadMsg{err: fmt.Errorf("failed to download: %v", err)}
				}
			}
			filePath = outFile
		}

		f, err := os.Open(filePath)
		if err != nil {
			return loadMsg{err: err}
		}

		var streamer beep.StreamSeekCloser
		var format beep.Format
		ext := strings.ToLower(filepath.Ext(filePath))

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

func (m model) nextSong() (model, tea.Cmd) {
	if len(m.filteredTracks) == 0 {
		return m, nil
	}
	m.currentIndex++
	if m.currentIndex >= len(m.filteredTracks) {
		if m.loop {
			m.currentIndex = 0
		} else {
			m.currentIndex = len(m.filteredTracks) - 1
			if m.ctrl != nil {
				speaker.Lock()
				m.ctrl.Paused = true
				speaker.Unlock()
			}
			return m, nil
		}
	}
	m.loading = true
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
	m.loading = true
	return m, m.loadSongCmd(m.currentIndex)
}
