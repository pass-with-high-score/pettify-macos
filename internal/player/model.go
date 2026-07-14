package player

import (
	"sync"
	"time"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/textinput"
	"github.com/faiface/beep"
	"github.com/faiface/beep/effects"
)

type Track struct {
	Path   string
	Title  string
	Artist string
}

type Visualizer struct {
	streamer beep.Streamer
	samples  []float64
	mutex    sync.Mutex
}

func (v *Visualizer) Stream(samples [][2]float64) (n int, ok bool) {
	n, ok = v.streamer.Stream(samples)
	if n > 0 {
		v.mutex.Lock()
		v.samples = make([]float64, n)
		for i := 0; i < n; i++ {
			v.samples[i] = (samples[i][0] + samples[i][1]) / 2
		}
		v.mutex.Unlock()
	}
	return n, ok
}

func (v *Visualizer) Err() error {
	return v.streamer.Err()
}

type model struct {
	tracks         []Track
	filteredTracks []int
	currentIndex   int
	streamer       beep.StreamSeekCloser
	format         beep.Format
	ctrl           *beep.Ctrl
	volume         *effects.Volume
	visualizer     *Visualizer
	progress       progress.Model
	searchBar      textinput.Model
	addInput       textinput.Model
	searching      bool
	adding         bool
	addStatus      string
	quitting       bool
	loop           bool
	shuffle        bool
	err            error
	initialized    bool
	initRate       beep.SampleRate
	width          int
	pointA         int
	pointB         int
	abActive       bool
	loading        bool
	config         Config
}

type tickMsg time.Time
type loadMsg struct {
	streamer beep.StreamSeekCloser
	format   beep.Format
	err      error
}

type trackAddedMsg struct {
	track Track
	err   error
}
