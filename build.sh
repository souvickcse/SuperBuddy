#!/usr/bin/env bash
# Builds SpiderBuddy.app. Usage:
#   ./build.sh              -> Release build
#   ./build.sh Debug        -> Debug build
#   ./build.sh Release run  -> build then launch
set -euo pipefail
cd "$(dirname "$0")"

CONF="${1:-Release}"
DO_RUN="${2:-}"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required.  brew install xcodegen" >&2
  exit 1
fi

xcodegen generate

xcodebuild \
  -project SpiderBuddy.xcodeproj \
  -scheme SpiderBuddy \
  -configuration "$CONF" \
  -derivedDataPath build \
  build

APP="build/Build/Products/${CONF}/SpiderBuddy.app"
echo ""
echo "Built  ->  $APP"

if [ "$DO_RUN" = "run" ]; then
  open "$APP"
  echo "Spider Buddy is now on your desktop. Look for the spider in the menu bar."
fi
