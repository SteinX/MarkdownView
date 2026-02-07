#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT="MarkdownDemo.xcodeproj"
SCHEME="MarkdownDemoSnapshotTests"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro,OS=26.2"

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
