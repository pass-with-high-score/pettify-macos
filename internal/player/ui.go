package player

import (
	"bytes"
	"fmt"
	"math"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/faiface/beep"
	"github.com/faiface/beep/effects"
	"github.com/faiface/beep/speaker"
)

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
	waveStyle       = lipgloss.NewStyle().Foreground(accent)
	
	statusStyle = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder(), false, false, false, true).
			BorderForeground(accent).
			PaddingLeft(2).
			MarginTop(1)

	helpStyle = lipgloss.NewStyle().
			Foreground(subtle).
			MarginTop(1)
)

// Removed EQ and limiter logic to fix crackling issues.

func (m *model) updateStreamer() {
	if m.volume == nil || m.visualizer == nil {
		return
	}
	
	var finalStreamer beep.Streamer = m.volume
	if m.format.SampleRate != m.initRate && m.initialized {
		finalStreamer = beep.Resample(4, m.format.SampleRate, m.initRate, m.volume)
	}
	m.visualizer.streamer = finalStreamer
}

func addTrackCmd(query string) tea.Cmd {
	return func() tea.Msg {
		if strings.HasPrefix(query, "yt: ") || strings.HasPrefix(query, "yt:") {
			query = strings.TrimPrefix(query, "yt:")
			query = strings.TrimSpace(query)
			query = "ytsearch1:" + query
		} else if !strings.HasPrefix(query, "http") && !strings.HasPrefix(query, "/") && !strings.HasPrefix(query, "./") && !strings.HasPrefix(query, "~/") {
			query = "ytsearch1:" + query
		}

		if strings.HasPrefix(query, "ytsearch1:") || strings.HasPrefix(query, "http") {
			ytDlpPath := getInternalYtDlpPath()
			var stdout, stderr bytes.Buffer
			cmd := exec.Command(ytDlpPath, "--print", "%(title)s|%(id)s|%(url)s|%(uploader)s", query)
			cmd.Stdout = &stdout
			cmd.Stderr = &stderr
			if err := cmd.Run(); err != nil {
				return trackAddedMsg{err: fmt.Errorf("search failed: %v\n%s", err, stderr.String())}
			}
			
			parts := strings.Split(strings.TrimSpace(stdout.String()), "|")
			if len(parts) >= 3 {
				title := parts[0]
				id := parts[1]
				url := parts[2]
				finalURL := ""
				if strings.HasPrefix(url, "http") && url != "NA" {
					finalURL = url
				} else if id != "NA" && id != "" {
					finalURL = "https://youtu.be/" + id
				}
				if finalURL == "" {
					return trackAddedMsg{err: fmt.Errorf("could not resolve URL")}
				}
				artist := ""
				if len(parts) >= 4 { artist = parts[3] }
				return trackAddedMsg{track: Track{Path: finalURL, Title: title, Artist: artist}}
			}
			return trackAddedMsg{err: fmt.Errorf("no results")}
		}
		
		return trackAddedMsg{track: Track{Path: query, Title: filepath.Base(query)}}
	}
}

func (m *model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if m.adding {
		switch msg := msg.(type) {
		case tea.KeyMsg:
			switch msg.String() {
			case "esc":
				m.adding = false
				m.addInput.Blur()
				return m, nil
			case "enter":
				m.adding = false
				m.addInput.Blur()
				val := m.addInput.Value()
				if strings.TrimSpace(val) == "" {
					return m, nil
				}
				m.addInput.SetValue("")
				m.addStatus = "Searching YouTube / Local..."
				return m, addTrackCmd(val)
			}
		}
		var cmd tea.Cmd
		m.addInput, cmd = m.addInput.Update(msg)
		return m, cmd
	}

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
		
		query := strings.ToLower(m.searchBar.Value())
		var filtered []int
		for i, t := range m.tracks {
			if strings.Contains(strings.ToLower(t.Title), query) || strings.Contains(strings.ToLower(t.Artist), query) {
				filtered = append(filtered, i)
			}
		}
		m.filteredTracks = filtered
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

	case trackAddedMsg:
		m.addStatus = "" // clear searching message
		if msg.err != nil {
			m.err = msg.err
			return m, nil
		}
		m.tracks = append(m.tracks, msg.track)
		m.filteredTracks = append(m.filteredTracks, len(m.tracks)-1)
		
		// If nothing is playing (e.g. empty queue or finished), play it immediately
		if m.streamer == nil && !m.loading {
			m.currentIndex = len(m.filteredTracks) - 1
			m.loading = true
			return m, m.loadSongCmd(m.filteredTracks[m.currentIndex])
		}
		return m, nil

	case loadMsg:
		m.loading = false
		if msg.err != nil {
			m.err = msg.err
			return m, tea.Quit
		}

		if m.streamer != nil {
			m.streamer.Close()
		}

		m.streamer = msg.streamer
		m.format = msg.format
		m.abActive = false
		m.lastPos = 0
		m.stalledTicks = 0
		
		m.ctrl = &beep.Ctrl{Streamer: m.streamer, Paused: false}
		m.volume = &effects.Volume{Streamer: m.ctrl, Base: 2, Volume: m.config.Volume, Silent: false}
		
		m.visualizer = &Visualizer{} // initialized empty to satisfy updateStreamer
		
		if !m.initialized {
			speaker.Init(m.format.SampleRate, m.format.SampleRate.N(time.Second/10))
			m.initRate = m.format.SampleRate
			m.initialized = true
		}

		m.updateStreamer()

		speaker.Clear()
		speaker.Play(m.visualizer)
		return m, nil

	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		case "a":
			m.adding = true
			m.addInput.Focus()
			return m, nil
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
		case "n":
			return m.nextSong()
		case "p":
			return m.prevSong()
		case "l":
			m.loop = !m.loop
		case "s":
			m.shuffle = !m.shuffle
		case "up":
			if m.volume != nil {
				speaker.Lock()
				m.volume.Volume += 0.1
				m.config.Volume = m.volume.Volume
				speaker.Unlock()
				go saveConfig(m.config)
			}
		case "down":
			if m.volume != nil {
				speaker.Lock()
				m.volume.Volume -= 0.1
				m.config.Volume = m.volume.Volume
				speaker.Unlock()
				go saveConfig(m.config)
			}
		case "j", "left":
			if m.streamer != nil {
				speaker.Lock()
				newPos := m.streamer.Position() - m.format.SampleRate.N(time.Second*10)
				if newPos < 0 {
					newPos = 0
				}
				m.streamer.Seek(newPos)
				speaker.Unlock()
			}
		case "k", "right":
			if m.streamer != nil {
				speaker.Lock()
				newPos := m.streamer.Position() + m.format.SampleRate.N(time.Second*10)
				if newPos >= m.streamer.Len() {
				} else {
					m.streamer.Seek(newPos)
				}
				speaker.Unlock()
			}
		case "[":
			if m.streamer != nil {
				speaker.Lock()
				m.pointA = m.streamer.Position()
				speaker.Unlock()
				m.abActive = false
			}
		case "]":
			if m.streamer != nil {
				speaker.Lock()
				pos := m.streamer.Position()
				speaker.Unlock()
				if pos > m.pointA {
					m.pointB = pos
					m.abActive = true
				}
			}
		case "\\":
			m.abActive = false
		}

	case tickMsg:
		if m.quitting {
			return m, nil
		}
		if m.streamer != nil {
			speaker.Lock()
			pos := m.streamer.Position()
			length := m.streamer.Len()
			speaker.Unlock()

			if m.abActive && pos >= m.pointB {
				speaker.Lock()
				m.streamer.Seek(m.pointA)
				speaker.Unlock()
			}
			
			isPaused := false
			if m.ctrl != nil {
				isPaused = m.ctrl.Paused
			}
			
			if pos >= length || (m.lastPos == pos && !isPaused && pos > 0 && !m.loading) {
				m.stalledTicks++
				if m.stalledTicks > 3 {
					m.stalledTicks = 0
					nm, cmd := m.nextSong()
					if nm.quitting {
						return nm, cmd
					}
					return nm, cmd
				}
			} else {
				m.stalledTicks = 0
			}
			m.lastPos = pos
		}
		return m, tick()

	case seekMsg:
		if m.streamer != nil {
			if pos, err := strconv.ParseFloat(msg.pos, 64); err == nil {
				speaker.Lock()
				m.streamer.Seek(m.format.SampleRate.N(time.Duration(pos * float64(time.Second))))
				speaker.Unlock()
			}
		}
		return m, nil

	case volMsg:
		if m.volume != nil {
			if volLinear, err := strconv.ParseFloat(msg.vol, 64); err == nil {
				speaker.Lock()
				if volLinear <= 0.01 {
					m.volume.Silent = true
				} else {
					m.volume.Silent = false
					// Map linear 0.0 - 1.0 to beep's logarithmic Volume (Base 2)
					// Base^Volume = volLinear => Volume = log2(volLinear)
					m.volume.Volume = math.Log2(volLinear)
				}
				m.config.Volume = volLinear
				speaker.Unlock()
				go saveConfig(m.config)
			}
		}
		return m, nil

	case toggleMsg:
		if m.ctrl != nil {
			speaker.Lock()
			m.ctrl.Paused = !m.ctrl.Paused
			speaker.Unlock()
		}
		return m, nil
	
	case nextTrackMsg:
		return m.nextSong()

	case prevTrackMsg:
		return m.prevSong()

	case progress.FrameMsg:
		progressModel, cmd := m.progress.Update(msg)
		m.progress = progressModel.(progress.Model)
		return m, cmd
	}

	return m, nil
}

func (m *model) View() string {
	if m.err != nil {
		return fmt.Sprintf("\n  Error: %v\n", m.err)
	}
	if m.quitting {
		return "\n  Playlist finished. Goodbye!\n"
	}

	if m.loading {
		return "\n  " + dimStyle.Render("Loading...") + "\n"
	}

	if len(m.filteredTracks) == 0 {
		return "\n  No tracks found.\n"
	}
	
	var percent float64
	var elapsed, total time.Duration
	if m.streamer != nil {
		speaker.Lock()
		pos := m.streamer.Position()
		length := m.streamer.Len()
		speaker.Unlock()
		
		percent = float64(pos) / float64(length)
		elapsed = m.format.SampleRate.D(pos).Round(time.Second)
		total = m.format.SampleRate.D(length).Round(time.Second)
	}

	status := "PLAYING"
	if m.ctrl != nil && m.ctrl.Paused {
		status = "PAUSED "
	}

	s := "\n" + titleStyle.Render("AUDIO PLAYER") + "\n\n"
	
	if m.loading {
		s += " ⏳ Loading track... (Downloading from YouTube if needed)\n\n"
	} else if len(m.filteredTracks) > 0 {
		track := m.tracks[m.filteredTracks[m.currentIndex]]
		displayTitle := track.Title
		if track.Artist != "" {
			displayTitle = fmt.Sprintf("%s - %s", track.Artist, track.Title)
		}
		s += nowPlayingStyle.Render("Now Playing: ") + displayTitle + "\n"
		s += m.progress.ViewAs(percent) + "\n"

		if m.visualizer != nil {
			m.visualizer.mutex.Lock()
			samples := m.visualizer.samples
			m.visualizer.mutex.Unlock()

			if len(samples) > 0 {
				waveWidth := 40
				if m.width > 20 {
					waveWidth = m.width - 10
				}
				if waveWidth > 80 {
					waveWidth = 80
				}

				wave := ""
				blocks := []string{" ", " ", "▂", "▃", "▄", "▅", "▆", "▇", "█"}

				step := len(samples) / waveWidth
				if step == 0 {
					step = 1
				}

				for i := 0; i < waveWidth; i++ {
					idx := i * step
					if idx >= len(samples) {
						break
					}

					amp := samples[idx]
					if amp < 0 {
						amp = -amp
					}
					if amp > 1 {
						amp = 1
					}

					blockIdx := int(amp * float64(len(blocks)-1))
					wave += waveStyle.Render(blocks[blockIdx])
				}
				s += " " + wave + "\n"
			}
		}

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
		s += statusStyle.Render(statusInfo) + "\n"
	} else if !m.loading {
		s += "No tracks found matching search.\n\n"
	}

	if m.searching {
		s += "\n Search: " + m.searchBar.View() + "\n"
	} else if m.adding {
		s += "\n Add Track: " + m.addInput.View() + "\n"
	} else {
		if m.addStatus != "" {
			s += "\n ⏳ " + dimStyle.Render(m.addStatus) + "\n"
		}
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

	s += helpStyle.Render("Space: Pause • N/P: Next/Prev • Left/Right: Seek • Up/Down: Vol • /: Search • A: Add • Q: Quit") + "\n"

	return s
}
