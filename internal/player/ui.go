package player

import (
	"fmt"
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
		m.abActive = false
		
		m.ctrl = &beep.Ctrl{Streamer: m.streamer, Paused: false}
		m.volume = &effects.Volume{Streamer: m.ctrl, Base: 2, Volume: 0, Silent: false}
		m.visualizer = &Visualizer{streamer: m.volume}

		if !m.initialized {
			speaker.Init(m.format.SampleRate, m.format.SampleRate.N(time.Second/10))
			m.initialized = true
		}

		speaker.Clear()
		speaker.Play(m.visualizer)
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
				speaker.Unlock()
			}
		case "down":
			if m.volume != nil {
				speaker.Lock()
				m.volume.Volume -= 0.1
				speaker.Unlock()
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
			if pos >= length {
				nm, cmd := m.nextSong()
				if nm.quitting {
					return nm, cmd
				}
				return nm, cmd
			}
		}
		return m, tick()

	case progress.FrameMsg:
		progressModel, cmd := m.progress.Update(msg)
		m.progress = progressModel.(progress.Model)
		return m, cmd
	}

	return m, nil
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
	
	if len(m.filteredTracks) > 0 {
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
	} else {
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

	s += helpStyle.Render("Space: Pause • N/P: Next/Prev • Left/Right: Seek • Up/Down: Vol • []: A-B • \\: Clear • /: Search • Q: Quit") + "\n"

	return s
}
