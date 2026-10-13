#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from Tools/icon.swift (needs the Xcode toolchain).
set -euo pipefail
cd "$(dirname "$0")/.."

mkdir -p .build .mcache
swiftc -parse-as-library -module-cache-path "$PWD/.mcache" -o .build/icon Tools/icon.swift
./.build/icon .build/icon_1024.png

rm -rf .build/AppIcon.iconset
mkdir -p .build/AppIcon.iconset
for spec in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
            "128 128x128" "256 128x128@2x" "256 256x256" \
            "512 256x256@2x" "512 512x512" "1024 512x512@2x"; do
  set -- $spec
  sips -z "$1" "$1" .build/icon_1024.png --out ".build/AppIcon.iconset/icon_$2.png" >/dev/null
done

mkdir -p Resources
iconutil -c icns .build/AppIcon.iconset -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
