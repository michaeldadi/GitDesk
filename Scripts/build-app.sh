#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

swift build -c release
bin_path="$(swift build -c release --show-bin-path)"
app_path="$repo_root/dist/GitDesk.app"

rm -rf "$app_path"
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"
cp "$bin_path/GitDeskApp" "$app_path/Contents/MacOS/GitDeskApp"
cp "$bin_path/gitdesk" "$app_path/Contents/MacOS/gitdesk"

cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleExecutable</key><string>GitDeskApp</string>
  <key>CFBundleIdentifier</key><string>dev.michaeldadi.GitDesk</string>
  <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
  <key>CFBundleName</key><string>GitDesk</string>
  <key>CFBundleDisplayName</key><string>GitDesk</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>27.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>CFBundleIconFile</key><string>GitDesk</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key><string>dev.michaeldadi.GitDesk</string>
      <key>CFBundleURLSchemes</key><array><string>gitdesk</string></array>
    </dict>
  </array>
</dict>
</plist>
PLIST

if [[ -f "$repo_root/Assets/GitDesk.icns" ]]; then
  cp "$repo_root/Assets/GitDesk.icns" "$app_path/Contents/Resources/GitDesk.icns"
fi

codesign --force --sign - "$app_path"
echo "$app_path"
