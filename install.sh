#!/usr/bin/env bash
set -e

echo "🎵 Building audio-cli..."
go build -v -o audio-cli ./cmd/audio-cli

echo "🚀 Installing to /usr/local/bin/audio-cli..."
# Install to /usr/local/bin, requiring sudo if not writable
if [ -w "/usr/local/bin" ]; then
    mv audio-cli /usr/local/bin/
else
    echo "Sudo permission is required to install to /usr/local/bin/"
    sudo mv audio-cli /usr/local/bin/
fi

echo "✅ Installation complete! You can now run 'audio-cli' from anywhere."
