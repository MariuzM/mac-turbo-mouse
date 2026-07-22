#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP=build/TurboMouse.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

cp .build/release/TurboMouse "$APP/Contents/MacOS/TurboMouse"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleIdentifier</key>
	<string>dev.marius.turbomouse</string>
	<key>CFBundleName</key>
	<string>Turbo Mouse</string>
	<key>CFBundleExecutable</key>
	<string>TurboMouse</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.2.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string></string>
</dict>
</plist>
EOF

IDENTITY="${CODESIGN_IDENTITY:-macOS Utility Dev}"
if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
  codesign --force --options runtime --sign "$IDENTITY" "$APP"
  echo "Signed with $IDENTITY"
else
  codesign --force --sign - "$APP"
  echo "Signed ad-hoc ($IDENTITY not found) — TCC grants will reset on rebuild"
fi
echo "Built $APP"
