#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PROJECT=""
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
TARGET="all"

for arg in "$@"; do
  case "$arg" in
    --record)
      SNAPSHOT_RECORDING="1"
      ;;
    --app)
      TARGET="app"
      ;;
    --library)
      TARGET="library"
      ;;
  esac
done

if [ "$SNAPSHOT_RECORDING" = "1" ]; then
  echo "Recording mode enabled (SNAPSHOT_RECORDING=1)"
else
  echo "Verify mode (SNAPSHOT_RECORDING=0)"
fi

run_app_snapshots() {
  echo ""
  echo "=== App Snapshot Tests (MarkdownDemoSnapshotTests) ==="
  TEST_RUNNER_SNAPSHOT_RECORDING="$SNAPSHOT_RECORDING" \
  xcodebuild test -project "$PROJECT" -scheme "MarkdownDemoSnapshotTests" -destination "$DESTINATION"
}

run_library_snapshots() {
  echo ""
  echo "=== Library Snapshot Tests (STXMarkdownView) ==="

  local sandbox
  sandbox="$(mktemp -d "${TMPDIR:-/tmp}/stxmarkdown-snapshot.XXXXXX")"
  trap 'rm -rf "$sandbox"' RETURN

  ln -s "$ROOT_DIR/Package.swift" "$sandbox/Package.swift"
  [ -f "$ROOT_DIR/Package.resolved" ] && ln -s "$ROOT_DIR/Package.resolved" "$sandbox/Package.resolved"
  ln -s "$ROOT_DIR/STXMarkdownView" "$sandbox/STXMarkdownView"

  cd "$sandbox"
  TEST_RUNNER_SNAPSHOT_RECORDING="$SNAPSHOT_RECORDING" \
  xcodebuild test \
    -scheme STXMarkdownView \
    -destination "$DESTINATION" \
    -only-testing:STXMarkdownViewTests/MarkdownViewSnapshotTests \
    CODE_SIGNING_ALLOWED=NO \
    2>&1
  cd "$ROOT_DIR"
}

EXIT_CODE=0

case "$TARGET" in
  app)
    run_app_snapshots || EXIT_CODE=$?
    ;;
  library)
    run_library_snapshots || EXIT_CODE=$?
    ;;
  all)
    run_app_snapshots || EXIT_CODE=$?
    run_library_snapshots || EXIT_CODE=$?
    ;;
esac

exit $EXIT_CODE
