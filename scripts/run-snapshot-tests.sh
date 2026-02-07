#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="MarkdownDemo.xcodeproj"
SCHEME="MarkdownDemoSnapshotTests"

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

if [ "${1:-}" = "--record" ]; then
  swift -e 'import Foundation
let url = URL(fileURLWithPath: "MarkdownDemoSnapshotTests/MarkdownDemoSnapshotTests.swift")
let text = try String(contentsOf: url)
let updated = text.replacingOccurrences(of: "isRecording = false", with: "isRecording = true")
try updated.write(to: url, atomically: true, encoding: .utf8)
'
  echo "Recording mode enabled in MarkdownDemoSnapshotTests.swift"
else
  swift -e 'import Foundation
let url = URL(fileURLWithPath: "MarkdownDemoSnapshotTests/MarkdownDemoSnapshotTests.swift")
let text = try String(contentsOf: url)
let updated = text.replacingOccurrences(of: "isRecording = true", with: "isRecording = false")
try updated.write(to: url, atomically: true, encoding: .utf8)
'
  echo "Recording mode disabled in MarkdownDemoSnapshotTests.swift"
fi

xcodebuild test -project "$PROJECT" -scheme "$SCHEME" -destination "$DESTINATION"
