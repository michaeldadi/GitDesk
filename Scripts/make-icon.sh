#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
iconset="$repo_root/Assets/GitDesk.iconset"
mkdir -p "$iconset"
swift "$repo_root/Scripts/make-icon.swift" "$iconset/icon_512x512@2x.png"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$iconset/icon_512x512@2x.png" \
    --out "$iconset/icon_${size}x${size}.png" >/dev/null
  twice=$((size * 2))
  sips -z "$twice" "$twice" "$iconset/icon_512x512@2x.png" \
    --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$iconset" -o "$repo_root/Assets/GitDesk.icns"
rm -rf "$iconset"
