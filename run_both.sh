#!/bin/bash
echo "🎵 Khởi động Audio CLI Backend..."
go build -o audio-cli-bin ./cmd/audio-cli
./audio-cli-bin "$@" &
GO_PID=$!

echo "🍎 Khởi động Giao diện Swift Menu Bar..."
cd macos-menubar && swift build -c release
./.build/release/macos-menubar &
SWIFT_PID=$!

function cleanup {
    echo ""
    echo "Đang tắt mọi thứ..."
    kill $SWIFT_PID
    kill $GO_PID
    exit
}

trap cleanup EXIT INT TERM

echo "✅ Đã xong! Hãy nhìn lên thanh Menu Bar của Mac, bấm vào hình nốt nhạc nhé!"
wait $GO_PID
