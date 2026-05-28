#!/bin/bash
set -e

# Define directories
WORKSPACE_DIR="/Users/jarkko/_dev/agy-test1"
BUILD_DIR="$WORKSPACE_DIR/build"
APP_DIR="$BUILD_DIR/AgyFinder.app"
TARGET_DIR="$HOME/Applications"
INSTALL_PATH="$TARGET_DIR/AgyFinder.app"

echo "=== 1. Building executable in release mode ==="
cd "$WORKSPACE_DIR"
swift build -c release

# Get compiled executable path
EXECUTABLE_SRC="$WORKSPACE_DIR/.build/release/agy-test1"

if [ ! -f "$EXECUTABLE_SRC" ]; then
    echo "Error: Compiled executable not found at $EXECUTABLE_SRC"
    exit 1
fi

echo "=== 2. Creating macOS App Bundle structure ==="
rm -rf "$BUILD_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "=== 3. Copying executable and writing Info.plist ==="
cp "$EXECUTABLE_SRC" "$APP_DIR/Contents/MacOS/AgyFinder"

if [ -f "$WORKSPACE_DIR/Resources/AppIcon.icns" ]; then
    cp "$WORKSPACE_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "Bundled AppIcon.icns"
fi

# Get current git tag or fallback to v1.0.0
VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
# Strip leading 'v' if present for CFBundleShortVersionString
SHORT_VERSION=$(echo "$VERSION" | sed 's/^v//')

cat << EOF > "$APP_DIR/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0//EN">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AgyFinder</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.ljack.agy-finder</string>
    <key>CFBundleName</key>
    <string>Agy Finder</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "=== 4. Releasing to ~/Applications ==="
mkdir -p "$TARGET_DIR"

# Clean previous installation if any
if [ -d "$INSTALL_PATH" ]; then
    echo "Removing previous installation at $INSTALL_PATH"
    rm -rf "$INSTALL_PATH"
fi

cp -R "$APP_DIR" "$INSTALL_PATH"
echo "Successfully installed AgyFinder.app to $INSTALL_PATH"

echo "=== 5. Restarting application ==="
echo "Terminating running instances..."
killall agy-test1 2>/dev/null || true
killall AgyFinder 2>/dev/null || true

# Wait a brief moment for processes to exit
sleep 1

echo "Launching $INSTALL_PATH..."
open "$INSTALL_PATH"

echo "=== Build and installation complete! ==="
