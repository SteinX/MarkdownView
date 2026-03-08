#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$ROOT_DIR"

PACKAGE_TEST_ROOT="$ROOT_DIR"
PACKAGE_SANDBOX=""

if [ -d "$ROOT_DIR/MarkdownDemo.xcodeproj" ]; then
  PACKAGE_SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/stxmarkdown-spm-tests.XXXXXX")"
  trap 'rm -rf "$PACKAGE_SANDBOX"' EXIT

  ln -s "$ROOT_DIR/Package.swift" "$PACKAGE_SANDBOX/Package.swift"
  if [ -f "$ROOT_DIR/Package.resolved" ]; then
    ln -s "$ROOT_DIR/Package.resolved" "$PACKAGE_SANDBOX/Package.resolved"
  fi
  ln -s "$ROOT_DIR/STXMarkdownView" "$PACKAGE_SANDBOX/STXMarkdownView"

  PACKAGE_TEST_ROOT="$PACKAGE_SANDBOX"
  echo "Using package-only sandbox: $PACKAGE_TEST_ROOT"
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
echo "Using simulator: $SIMULATOR_NAME"

XCODEBUILD_ARGS=(
  test
  -scheme STXMarkdownView
  -destination "platform=iOS Simulator,name=$SIMULATOR_NAME"
  CODE_SIGNING_ALLOWED=NO
)

if [ -n "${RESULT_BUNDLE_PATH:-}" ]; then
  XCODEBUILD_ARGS+=("-resultBundlePath" "$RESULT_BUNDLE_PATH")
fi

cd "$PACKAGE_TEST_ROOT"
xcodebuild "${XCODEBUILD_ARGS[@]}" 2>&1
