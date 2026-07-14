package player

import (
	"encoding/json"
	"net/http"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/faiface/beep/speaker"
)

var (
	apiModel *model
	apiProg  *tea.Program
)

type StatusResponse struct {
	Title     string  `json:"title"`
	Artist    string  `json:"artist"`
	Thumbnail string  `json:"thumbnail"`
	Paused    bool    `json:"paused"`
	Volume       float64 `json:"volume"`
	Percent      float64 `json:"percent"`
	Position     float64 `json:"position"`
	Duration     float64 `json:"duration"`
	SearchStatus string  `json:"searchStatus"`
}

func getThumbnail(url string) string {
	if strings.Contains(url, "youtu.be/") {
		id := strings.Split(url, "youtu.be/")[1]
		if i := strings.Index(id, "?"); i != -1 {
			id = id[:i]
		}
		return "https://img.youtube.com/vi/" + id + "/hqdefault.jpg"
	}
	if strings.Contains(url, "youtube.com/watch?v=") {
		id := strings.Split(url, "v=")[1]
		if i := strings.Index(id, "&"); i != -1 {
			id = id[:i]
		}
		return "https://img.youtube.com/vi/" + id + "/hqdefault.jpg"
	}
	return ""
}

func handleStatus(w http.ResponseWriter, r *http.Request) {
	if apiModel == nil {
		http.Error(w, "Not ready", 503)
		return
	}

	m := apiModel // copy pointer
	if len(m.filteredTracks) == 0 {
		json.NewEncoder(w).Encode(StatusResponse{Title: "No track playing"})
		return
	}
	if m.loading {
		json.NewEncoder(w).Encode(StatusResponse{Title: "Loading..."})
		return
	}

	track := m.tracks[m.filteredTracks[m.currentIndex]]
	
	paused := false
	if m.ctrl != nil {
		paused = m.ctrl.Paused
	}
	
	vol := 1.0
	if m.volume != nil {
		vol = m.volume.Volume
	}

	percent := 0.0
	posSeconds := 0.0
	durSeconds := 0.0
	if m.streamer != nil {
		speaker.Lock()
		pos := m.streamer.Position()
		length := m.streamer.Len()
		speaker.Unlock()
		
		percent = float64(pos) / float64(length)
		posSeconds = m.format.SampleRate.D(pos).Seconds()
		durSeconds = m.format.SampleRate.D(length).Seconds()
	}

	resp := StatusResponse{
		Title:     track.Title,
		Artist:    track.Artist,
		Thumbnail: getThumbnail(track.Path),
		Paused:    paused,
		Volume:       vol,
		Percent:      percent,
		Position:     posSeconds,
		Duration:     durSeconds,
		SearchStatus: m.addStatus,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func handlePlayPause(w http.ResponseWriter, r *http.Request) {
	if apiProg != nil {
		apiProg.Send(toggleMsg{})
	}
	w.WriteHeader(200)
}

func handleNext(w http.ResponseWriter, r *http.Request) {
	if apiProg != nil {
		apiProg.Send(nextTrackMsg{})
	}
	w.WriteHeader(200)
}

func handlePrev(w http.ResponseWriter, r *http.Request) {
	if apiProg != nil {
		apiProg.Send(prevTrackMsg{})
	}
	w.WriteHeader(200)
}

func handleSeek(w http.ResponseWriter, r *http.Request) {
	posStr := r.URL.Query().Get("pos")
	if posStr != "" {
		if apiProg != nil {
			apiProg.Send(seekMsg{posStr})
		}
	}
	w.WriteHeader(200)
}

func handleVolume(w http.ResponseWriter, r *http.Request) {
	volStr := r.URL.Query().Get("vol")
	if volStr != "" {
		if apiProg != nil {
			apiProg.Send(volMsg{volStr})
		}
	}
	w.WriteHeader(200)
}

func handleAdd(w http.ResponseWriter, r *http.Request) {
	query := r.URL.Query().Get("q")
	if query != "" && apiProg != nil {
		apiProg.Send(apiAddTrackMsg{query: query})
	}
	w.WriteHeader(200)
}

func handleQuit(w http.ResponseWriter, r *http.Request) {
	if apiProg != nil {
		apiProg.Send(tea.QuitMsg{})
	}
	w.WriteHeader(200)
}

func startAPI(p *tea.Program, m *model) {
	apiProg = p
	apiModel = m
	http.HandleFunc("/status", handleStatus)
	http.HandleFunc("/playpause", handlePlayPause)
	http.HandleFunc("/next", handleNext)
	http.HandleFunc("/prev", handlePrev)
	http.HandleFunc("/seek", handleSeek)
	http.HandleFunc("/volume", handleVolume)
	http.HandleFunc("/add", handleAdd)
	http.HandleFunc("/quit", handleQuit)
	go http.ListenAndServe(":13337", nil)
}

type toggleMsg struct{}
type nextTrackMsg struct{}
type prevTrackMsg struct{}
type seekMsg struct{ pos string }
type volMsg struct{ vol string }
type apiAddTrackMsg struct{ query string }
