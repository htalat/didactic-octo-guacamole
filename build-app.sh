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
    <string>com.htalat.todo</string>
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

# Make executable executable
chmod +x "$BUNDLE_DIR/MacOS/Todo"

# Code sign the app bundle
if command -v codesign >/dev/null 2>&1; then
    echo "Code signing the app..."
    codesign --force --deep --sign - "$APP_NAME"
    if [ $? -eq 0 ]; then
        echo "✅ App successfully signed"
    else
        echo "⚠️  Code signing failed, app will need manual approval"
    fi
else
    echo "⚠️  codesign not found, app will need manual approval"
fi

# Create DMG for distribution
DMG_NAME="Todo-v3.0.1.dmg"
echo "Creating DMG..."
hdiutil create -volname "Todo" -srcfolder "$APP_NAME" -ov -format UDZO "$DMG_NAME"

echo ""
echo "✅ App bundle created: $APP_NAME"
echo "✅ DMG created: $DMG_NAME"
echo ""
echo "For distribution: Share the DMG file"
echo "For local use: open $APP_NAME"