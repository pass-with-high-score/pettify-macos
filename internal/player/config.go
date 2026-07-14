package player

import (
	"encoding/json"
	"os"
	"path/filepath"
)

type Config struct {
	Volume float64 `json:"volume"`
	Bass   float64 `json:"bass"`
	Mid    float64 `json:"mid"`
	Treble float64 `json:"treble"`
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
