package player

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
)

func getInternalYtDlpPath() string {
	configDir, err := os.UserConfigDir()
	if err != nil {
		configDir = "."
	}
	dir := filepath.Join(configDir, "audio-cli")
	os.MkdirAll(dir, 0755)

	if runtime.GOOS == "windows" {
		return filepath.Join(dir, "yt-dlp.exe")
	}
	return filepath.Join(dir, "yt-dlp")
}

func ensureYtDlp() (string, error) {
	path := getInternalYtDlpPath()
	if _, err := os.Stat(path); err == nil {
		return path, nil
	}

	fmt.Println("📥 Downloading internal yt-dlp... (This only happens once)")

	var url string
	switch runtime.GOOS {
	case "windows":
		url = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
	case "darwin":
		url = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"
	default: // linux, etc.
		url = "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
	}

	resp, err := http.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to download yt-dlp: %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("bad status: %s", resp.Status)
	}

	out, err := os.Create(path)
	if err != nil {
		return "", err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return "", err
	}

	// Make executable
	if runtime.GOOS != "windows" {
		os.Chmod(path, 0755)
	}

	return path, nil
}
