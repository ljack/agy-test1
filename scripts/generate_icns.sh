#!/bin/bash
set -e

RAW_IMAGE="/Users/jarkko/.gemini/antigravity/brain/096a8914-5949-4d3b-b578-2d09646f6628/app_icon_raw_1779985124044.png"
ICONSET="AppIcon.iconset"
OUTPUT_DIR="Resources"
OUTPUT_FILE="$OUTPUT_DIR/AppIcon.icns"

if [ ! -f "$RAW_IMAGE" ]; then
    echo "Error: Raw image not found at $RAW_IMAGE"
    exit 1
fi

echo "=== Creating output directory and iconset ==="
mkdir -p "$OUTPUT_DIR"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

echo "=== Resizing and converting icons to PNG using sips ==="
sips -s format png -z 16 16     "$RAW_IMAGE" --out "$ICONSET/icon_16x16.png" > /dev/null
sips -s format png -z 32 32     "$RAW_IMAGE" --out "$ICONSET/icon_16x16@2x.png" > /dev/null
sips -s format png -z 32 32     "$RAW_IMAGE" --out "$ICONSET/icon_32x32.png" > /dev/null
sips -s format png -z 64 64     "$RAW_IMAGE" --out "$ICONSET/icon_32x32@2x.png" > /dev/null
sips -s format png -z 128 128   "$RAW_IMAGE" --out "$ICONSET/icon_128x128.png" > /dev/null
sips -s format png -z 256 256   "$RAW_IMAGE" --out "$ICONSET/icon_128x128@2x.png" > /dev/null
sips -s format png -z 256 256   "$RAW_IMAGE" --out "$ICONSET/icon_256x256.png" > /dev/null
sips -s format png -z 512 512   "$RAW_IMAGE" --out "$ICONSET/icon_256x256@2x.png" > /dev/null
sips -s format png -z 512 512   "$RAW_IMAGE" --out "$ICONSET/icon_512x512.png" > /dev/null
sips -s format png -z 1024 1024 "$RAW_IMAGE" --out "$ICONSET/icon_512x512@2x.png" > /dev/null

echo "=== Compiling to icns ==="
iconutil -c icns "$ICONSET" -o "$OUTPUT_FILE"

echo "=== Cleaning up temporary iconset ==="
rm -rf "$ICONSET"

echo "=== Successfully created $OUTPUT_FILE! ==="
