#!/bin/bash
set -e

VERSION="3.1.1"
APP_NAME="Todo.app"
DMG_NAME="Todo-v${VERSION}.dmg"
BUNDLE_DIR="$APP_NAME/Contents"
SIGNING_IDENTITY="Developer ID Application: Hassan Talat (5SY7TU5TAQ)"
NOTARY_PROFILE="notarytool-profile"

echo "🔨 Building Todo v${VERSION}..."

# Build the app executable
swift build -c release --product TodoApp

# Create app bundle structure
rm -rf "$APP_NAME"
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
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

# Create entitlements file for hardened runtime
cat > "entitlements.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
</dict>
</plist>
EOF

# Make executable executable
chmod +x "$BUNDLE_DIR/MacOS/Todo"

# Code sign with hardened runtime
echo "🔐 Signing with Developer ID..."
codesign --force --options runtime --entitlements entitlements.plist --sign "$SIGNING_IDENTITY" "$APP_NAME"
echo "✅ Signed"

# Verify signature
echo "🔍 Verifying signature..."
codesign --verify --verbose "$APP_NAME"
spctl --assess --type exec --verbose "$APP_NAME" || echo "⚠️  Gatekeeper check will pass after notarization"

# Create DMG
echo "📦 Creating DMG..."
rm -f "$DMG_NAME"
hdiutil create -volname "Todo" -srcfolder "$APP_NAME" -ov -format UDZO "$DMG_NAME"

# Sign the DMG too
codesign --force --sign "$SIGNING_IDENTITY" "$DMG_NAME"

# Notarize
echo "🚀 Submitting for notarization (this may take a few minutes)..."
xcrun notarytool submit "$DMG_NAME" --keychain-profile "$NOTARY_PROFILE" --wait

# Staple the ticket
echo "📎 Stapling notarization ticket..."
xcrun stapler staple "$DMG_NAME"

# Final verification
echo "🔍 Final Gatekeeper check..."
spctl --assess --type open --context context:primary-signature --verbose "$DMG_NAME"

# Cleanup
rm -f entitlements.plist

echo ""
echo "✅ Done! $DMG_NAME is ready for distribution"
echo ""
echo "Users can now download and open it without Gatekeeper warnings 🎉"
