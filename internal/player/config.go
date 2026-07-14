package player

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type Config struct {
	Volume   float64 `json:"volume"`
	Band60   float64 `json:"band_60"`
	Band250  float64 `json:"band_250"`
	Band1k   float64 `json:"band_1k"`
	Band4k   float64 `json:"band_4k"`
	Band12k  float64 `json:"band_12k"`
}

func getConfigPath() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		configDir = "."
	}
	dir := filepath.Join(configDir, "audio-cli")
	os.MkdirAll(dir, 0755)
	return filepath.Join(dir, "config.json")
}

func loadConfig() Config {
	cfg := Config{Volume: 0} // Default volume
	
	path := getConfigPath()
	data, err := os.ReadFile(path)
	if err == nil {
		json.Unmarshal(data, &cfg)
	}
	return cfg
}

func saveConfig(cfg Config) {
	path := getConfigPath()
	data, err := json.MarshalIndent(cfg, "", "  ")
	if err == nil {
		os.WriteFile(path, data, 0644)
	}
}
