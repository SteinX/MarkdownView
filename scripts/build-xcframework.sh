#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ROOT_DIR="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  :
else
  ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

cd "$ROOT_DIR"

# Configuration
FRAMEWORK_NAME="STXMarkdownView"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/Frameworks}"
CONFIGURATION="${CONFIGURATION:-Release}"

# Derived paths
XCFRAMEWORK_PATH="$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
  log_info "Cleaning previous build artifacts..."
  rm -rf "$BUILD_DIR"
  rm -rf "$XCFRAMEWORK_PATH"
  mkdir -p "$BUILD_DIR"
  mkdir -p "$OUTPUT_DIR"
}

# Build using dynamic library Package.swift in a temp directory
build_dynamic_framework() {
  log_info "Building dynamic framework using temporary Package.swift..."
  
  local temp_dir="$BUILD_DIR/dynamic-build"
  mkdir -p "$temp_dir"
  
  # Create Package.swift with dynamic library type
  # This is the key: type: .dynamic produces a proper .framework bundle
  cat > "$temp_dir/Package.swift" << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "STXMarkdownView",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "STXMarkdownView",
            type: .dynamic,
            targets: ["STXMarkdownView"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown", from: "0.7.3")
    ],
    targets: [
        .target(
            name: "STXMarkdownView",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/STXMarkdownView"
        )
    ]
)
EOF

  # Create Sources directory structure matching the temp package
  mkdir -p "$temp_dir/Sources"
  cp -R "$ROOT_DIR/STXMarkdownView/Sources/STXMarkdownView" "$temp_dir/Sources/"
  
  cd "$temp_dir"
  
  local archive_dir="$BUILD_DIR/archives"
  mkdir -p "$archive_dir"
  
  # Archive for iOS device (arm64)
  log_info "Archiving for iOS device..."
  xcodebuild archive \
    -scheme "$FRAMEWORK_NAME" \
    -destination "generic/platform=iOS" \
    -archivePath "$archive_dir/ios.xcarchive" \
    -configuration "$CONFIGURATION" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | xcbeautify 2>/dev/null || cat
  
  # Archive for iOS Simulator (arm64 + x86_64)
  log_info "Archiving for iOS Simulator..."
  xcodebuild archive \
    -scheme "$FRAMEWORK_NAME" \
    -destination "generic/platform=iOS Simulator" \
    -archivePath "$archive_dir/ios-simulator.xcarchive" \
    -configuration "$CONFIGURATION" \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | xcbeautify 2>/dev/null || cat
  
  cd "$ROOT_DIR"
  
  # Find frameworks in archives
  local ios_framework
  local sim_framework
  
  ios_framework=$(find "$archive_dir/ios.xcarchive" -name "$FRAMEWORK_NAME.framework" -type d 2>/dev/null | head -1)
  sim_framework=$(find "$archive_dir/ios-simulator.xcarchive" -name "$FRAMEWORK_NAME.framework" -type d 2>/dev/null | head -1)
  
  if [ -z "$ios_framework" ] || [ -z "$sim_framework" ]; then
    log_error "Frameworks not found in archives"
    log_info "Searching for frameworks..."
    find "$archive_dir" -type d -name "*.framework" 2>/dev/null || true
    log_info "Searching for binaries..."
    find "$archive_dir" -type f \( -name "*.o" -o -name "*.dylib" -o -name "*.a" \) 2>/dev/null || true
    exit 1
  fi
  
  log_info "iOS Framework: $ios_framework"
  log_info "Simulator Framework: $sim_framework"
  
  # Create XCFramework
  xcodebuild -create-xcframework \
    -framework "$ios_framework" \
    -framework "$sim_framework" \
    -output "$XCFRAMEWORK_PATH"
  
  log_info "XCFramework created at: $XCFRAMEWORK_PATH"
}

show_usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Builds STXMarkdownView.xcframework for iOS distribution."
  echo ""
  echo "Options:"
  echo "  --clean          Clean build artifacts only"
  echo "  --skip-clean     Skip cleaning previous builds"
  echo "  --config NAME    Build configuration (Debug/Release, default: Release)"
  echo "  --output DIR     Output directory (default: ./output)"
  echo "  -h, --help       Show this help message"
  echo ""
  echo "Environment variables:"
  echo "  BUILD_DIR        Build directory (default: ./build)"
  echo "  OUTPUT_DIR       Output directory (default: ./output)"
  echo "  CONFIGURATION    Build configuration (default: Release)"
}

# Parse arguments
SKIP_CLEAN=false
CLEAN_ONLY=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --clean)
      CLEAN_ONLY=true
      shift
      ;;
    --skip-clean)
      SKIP_CLEAN=true
      shift
      ;;
    --config)
      CONFIGURATION="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      XCFRAMEWORK_PATH="$OUTPUT_DIR/$FRAMEWORK_NAME.xcframework"
      shift 2
      ;;
    -h|--help)
      show_usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      show_usage
      exit 1
      ;;
  esac
done

# Main execution
log_info "Building $FRAMEWORK_NAME.xcframework"
log_info "Configuration: $CONFIGURATION"
log_info "Output: $OUTPUT_DIR"

if [ "$CLEAN_ONLY" = true ]; then
  cleanup
  log_info "Clean completed."
  exit 0
fi

if [ "$SKIP_CLEAN" = false ]; then
  cleanup
fi

# Build using dynamic framework approach
build_dynamic_framework

# Show result
log_info ""
log_info "Build completed successfully!"
log_info ""
log_info "XCFramework location:"
log_info "  $XCFRAMEWORK_PATH"
log_info ""
log_info "To use with CocoaPods, add to your podspec:"
log_info "  s.vendored_frameworks = '$FRAMEWORK_NAME.xcframework'"
