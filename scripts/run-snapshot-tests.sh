#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT=""
SCHEME="MarkdownDemoSnapshotTests"

if [ -d "MarkdownDemo.xcodeproj" ]; then
  PROJECT="MarkdownDemo.xcodeproj"
elif [ -d ".MarkdownDemo.xcodeproj.hidden" ]; then
  PROJECT=".MarkdownDemo.xcodeproj.hidden"
  echo "Detected hidden project directory, using: $PROJECT"
else
  echo "Error: neither MarkdownDemo.xcodeproj nor .MarkdownDemo.xcodeproj.hidden exists." >&2
  exit 1
fi

detect_simulator() {
  local available_sims
  available_sims=$(xcrun simctl list devices available 2>/dev/null | grep -E "iPhone.*\(.*\)" | head -1)
  if [ -n "$available_sims" ]; then
    local sim_name
    sim_name=$(echo "$available_sims" | sed -E 's/^[[:space:]]*([^(]+) \(.*/\1/' | xargs)
    echo "$sim_name"
    return 0
  fi
  echo "iPhone 17 Pro"
}

SIMULATOR_NAME="${SIMULATOR_NAME:-$(detect_simulator)}"
DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME"
echo "Using simulator: $SIMULATOR_NAME"

SNAPSHOT_RECORDING="0"
if [ "${1:-}" = "--record" ]; then
  SNAPSHOT_RECORDING="1"
  echo "Recording mode enabled (SNAPSHOT_RECORDING=1)"
else
  echo "Recording mode disabled (SNAPSHOT_RECORDING=0)"
fi

SNAPSHOT_RECORDING="$SNAPSHOT_RECORDING" \
xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION"
