#!/bin/bash

# Build the app executable
swift build -c release --product TodoApp

# Create app bundle structure
APP_NAME="Todo.app"
BUNDLE_DIR="$APP_NAME/Contents"
mkdir -p "$BUNDLE_DIR/MacOS"
mkdir -p "$BUNDLE_DIR/Resources"

# Copy the executable
cp .build/release/TodoApp "$BUNDLE_DIR/MacOS/Todo"

# Create Info.plist
cat > "$BUNDLE_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Todo</string>
    <key>CFBundleIdentifier</key>
    <string>com.todo.app</string>
    <key>CFBundleName</key>
    <string>Todo</string>
    <key>CFBundleDisplayName</key>
    <string>Todo</string>
    <key>CFBundleVersion</key>
    <string>3.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>3.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

echo "App bundle created: $APP_NAME"
echo "Run: open $APP_NAME"