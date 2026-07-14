#!/usr/bin/env bash
set -e

echo "🎵 Installing audio-cli..."

if ! command -v go &> /dev/null
then
    echo "❌ Error: 'go' is not installed. Please install Go first."
    exit 1
fi

echo "=> Fetching and building via 'go install'..."
go install github.com/pass-with-high-score/audio-cli/cmd/audio-cli@latest

echo "✅ Installation complete!"
echo "Make sure your Go bin directory (usually ~/go/bin or \$GOPATH/bin) is in your \$PATH."
