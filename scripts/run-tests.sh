#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$ROOT_DIR"

PACKAGE_DIR="$ROOT_DIR/STXMarkdownView"

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
echo "Using simulator: $SIMULATOR_NAME"

cd "$PACKAGE_DIR"
xcodebuild test \
  -scheme STXMarkdownView \
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
  -derivedDataPath "$ROOT_DIR/.build/DerivedData-STXMarkdownView" \
  CODE_SIGNING_ALLOWED=NO \
  2>&1
