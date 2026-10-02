#!/bin/bash
# Builds Swaybles.app (universal: Apple Silicon + Intel), signs it ad-hoc and zips it.
#   mac/scripts/make-app.sh            → mac/dist/Swaybles.app + mac/dist/Swaybles-<version>.zip
# Needs Xcode (for the universal build). No Apple Developer account needed; without one,
# people open it the first time with right-click → Open.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(node -p "require('../package.json').version" 2>/dev/null || echo 1.0.0)}"
APP=dist/Swaybles.app
ICON_CHARM="${ICON_CHARM:-Resources/Charms/spooky-crew/skeleton.png}"

echo "→ swift test"
swift test

echo "→ building release (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Swaybles"

rm -rf "$APP" && mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Swaybles"
cp -R Resources/Charms "$APP/Contents/Resources/Charms"

# App icon from a charm: pad to a square, then every size macOS wants.
if [ -f "$ICON_CHARM" ]; then
  T=$(mktemp -d); mkdir "$T/AppIcon.iconset"
  sips -Z 820 "$ICON_CHARM" --out "$T/charm.png" >/dev/null
  sips -p 1024 1024 "$T/charm.png" --out "$T/square.png" >/dev/null
  for s in 16 32 128 256 512; do
    sips -z $s $s "$T/square.png" --out "$T/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$T/square.png" --out "$T/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$T/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
  rm -rf "$T"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Swaybles</string>
  <key>CFBundleDisplayName</key><string>Swaybles</string>
  <key>CFBundleIdentifier</key><string>com.swaybles.app</string>
  <key>CFBundleExecutable</key><string>Swaybles</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${VERSION}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
  <key>NSHumanReadableCopyright</key><string>Free and open source (MIT)</string>
</dict></plist>
PLIST

echo "→ signing (ad-hoc)"
codesign --force --deep --sign - "$APP"
codesign --verify --strict "$APP"

ZIP="dist/Swaybles-${VERSION}.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "✓ $APP  ($(du -sh "$APP" | cut -f1))"
echo "✓ $ZIP ($(du -h "$ZIP" | cut -f1)) — upload this to GitHub Releases"
