#!/bin/bash

APP_NAME="PingApp"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Build
swift build -c release

# Get Build Directory
BUILD_DIR=$(swift build -c release --show-bin-path)

# Create Bundle Structure
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy Binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Copy Info.plist
cp "Sources/PingApp/Resources/Info.plist" "$CONTENTS_DIR/"

# Set Permissions
chmod +x "$MACOS_DIR/$APP_NAME"

echo "$APP_NAME.app created successfully."
