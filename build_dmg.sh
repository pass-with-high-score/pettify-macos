#!/bin/bash

# Exit on error
set -e

APP_NAME="Petify"
APP_DIR="Petify.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🔨 Building Swift package for Universal macOS (Intel & Apple Silicon)..."
cd Petify
swift build -c release --arch arm64 --arch x86_64
BUILD_DIR=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)
cd ..

echo "📦 Creating .app bundle structure..."
rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "🚚 Copying binary and resources..."
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

# Copy Swift package resources bundle if it exists
if [ -d "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" ]; then
    cp -R "${BUILD_DIR}/${APP_NAME}_${APP_NAME}.bundle" "${RESOURCES_DIR}/"
fi

echo "🖼️ Generating App Icon (.icns)..."
ICONSET_DIR="Petify.iconset"
mkdir -p "${ICONSET_DIR}"

# Using the petify_logo.png to generate all icon sizes
LOGO="Petify/Sources/Petify/Resources/AppIcon.png"
if [ -f "$LOGO" ]; then
    sips -z 16 16     "$LOGO" --out "${ICONSET_DIR}/icon_16x16.png" > /dev/null
    sips -z 32 32     "$LOGO" --out "${ICONSET_DIR}/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$LOGO" --out "${ICONSET_DIR}/icon_32x32.png" > /dev/null
    sips -z 64 64     "$LOGO" --out "${ICONSET_DIR}/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$LOGO" --out "${ICONSET_DIR}/icon_128x128.png" > /dev/null
    sips -z 256 256   "$LOGO" --out "${ICONSET_DIR}/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$LOGO" --out "${ICONSET_DIR}/icon_256x256.png" > /dev/null
    sips -z 512 512   "$LOGO" --out "${ICONSET_DIR}/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$LOGO" --out "${ICONSET_DIR}/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$LOGO" --out "${ICONSET_DIR}/icon_512x512@2x.png" > /dev/null

    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf "${ICONSET_DIR}"
else
    echo "⚠️ Logo not found at $LOGO, skipping icon generation."
fi

echo "📄 Generating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>app.pwhs.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "💿 Creating DMG..."
DMG_NAME="${APP_NAME}.dmg"
rm -f "${DMG_NAME}"
# Create a temporary folder to wrap the app for DMG creation
TEMP_DMG_DIR="dmg_root"
mkdir -p "${TEMP_DMG_DIR}"
mv "${APP_DIR}" "${TEMP_DMG_DIR}/"
ln -s /Applications "${TEMP_DMG_DIR}/Applications"

hdiutil create -volname "${APP_NAME}" -srcfolder "${TEMP_DMG_DIR}" -ov -format UDZO "${DMG_NAME}"
rm -rf "${TEMP_DMG_DIR}"

echo "✅ Done! You can find your app at ${DMG_NAME}"
