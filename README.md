# MarkdownView

[![PR Unit Tests](https://github.com/SteinX/MarkdownView/actions/workflows/pr-tests.yml/badge.svg)](https://github.com/SteinX/MarkdownView/actions/workflows/pr-tests.yml)
[![Build XCFramework](https://github.com/SteinX/MarkdownView/actions/workflows/release-xcframework.yml/badge.svg)](https://github.com/SteinX/MarkdownView/actions/workflows/release-xcframework.yml)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange.svg)](https://swift.org)
[![iOS](https://img.shields.io/badge/iOS-15.0%2B-blue.svg)](https://developer.apple.com/ios/)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A high-performance Markdown rendering solution for iOS, featuring **STXMarkdownView** — a UITextView-based component optimized for chat-style UI with streaming support.

## Project Structure

```
MarkdownView/
├── STXMarkdownView/          # Swift Package - Core Markdown rendering library
│   ├── Sources/
│   │   └── STXMarkdownView/
│   │       ├── Core/         # Parser, Renderer, MarkdownView
│   │       ├── Views/        # CodeBlock, Table, Quote, Image views
│   │       ├── Theme/        # Customizable theming system
│   │       ├── Image/        # Image loading with caching
│   │       └── Utils/        # Logging, helpers
│   └── Tests/
├── MarkdownDemo/             # iOS demo application
├── MarkdownDemoSnapshotTests/ # Snapshot tests
└── MarkdownDemo.xcodeproj    # Xcode project
```

## Features

| Feature | Description |
|---------|-------------|
| **Rich Attachments** | Tables, code blocks, images, block quotes as embedded views |
| **Streaming Mode** | Throttled rendering for real-time chat/AI assistant UI |
| **Syntax Highlighting** | Optional Highlightr integration for code blocks |
| **Adaptive Tables** | Auto-switch between compact and scrollable layout |
| **Image Caching** | Memory + disk cache with async loading |
| **Theme System** | Fully customizable colors, fonts, and spacing |
| **Performance** | Attachment reuse, incremental rendering, minimal re-layouts |

## Requirements

- iOS 15.0+
- Swift 5.9+
- Xcode 15.0+

## Quick Start

### 1. Add STXMarkdownView to Your Project

**Swift Package Manager**

In Xcode: File → Add Package Dependencies → Enter the repository URL:

```
https://github.com/SteinX/MarkdownView
```

Or add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/SteinX/MarkdownView", from: "1.0.0")
]

// Then add to target dependencies:
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "STXMarkdownView", package: "MarkdownView")
    ]
)
```

**CocoaPods**

Add to your `Podfile`:

```ruby
pod 'STXMarkdownView', :git => 'https://github.com/SteinX/MarkdownView.git'

# Or specify a tag/branch
pod 'STXMarkdownView', :git => 'https://github.com/SteinX/MarkdownView.git', :tag => '1.0.0'
```

Then run:

```bash
pod install
```

### 2. Basic Usage

````swift
import STXMarkdownView

let markdownView = MarkdownView()
markdownView.markdown = """
# Hello Markdown

This is **bold** and `inline code`.

```swift
print("Hello, World!")
```
"""

view.addSubview(markdownView)
````

### 3. Streaming Mode (Chat UI)

Perfect for AI chat applications with real-time text generation:

```swift
// Enable streaming mode for throttled rendering
markdownView.isStreaming = true
markdownView.throttleInterval = 0.1  // 100ms throttle

// Update content incrementally
markdownView.markdown = partialText

// When streaming ends, trigger final render
markdownView.isStreaming = false
```

### 4. Theme Customization

```swift
var theme = MarkdownTheme.default
theme = MarkdownTheme(
    baseFont: .systemFont(ofSize: 16),
    colors: theme.colors,
    headings: theme.headings,
    code: theme.code,
    quote: theme.quote,
    lists: theme.lists,
    tables: theme.tables,
    images: theme.images
)
markdownView.theme = theme
```

### 5. Debug Logging

```swift
// Enable verbose logging (view in Console.app, filter: subsystem:com.app.markdown)
MarkdownView.logLevel = .verbose

// Other levels: .info, .error, .off
```

## Running the Demo

1. Open `MarkdownDemo.xcodeproj` in Xcode
2. Select a simulator or device
3. Build and run (Cmd+R)
4. Tap "Start Stream" to see streaming mode in action

## Architecture

```
MarkdownView (UIView)
    └── MarkdownTextView (UITextView)
            ├── NSAttributedString (text content)
            └── Attachments (embedded views)
                    ├── CodeBlockView
                    ├── MarkdownTableView
                    ├── QuoteView
                    ├── MarkdownImageView
                    └── HorizontalRuleView
```

**Key Components:**

- **MarkdownParser**: Converts Markdown → NSAttributedString + attachment placeholders
- **MarkdownRenderer**: Manages attachment view lifecycle and reuse
- **MarkdownTextView**: Custom UITextView with attachment layout support

## Dependencies

| Package | Purpose |
|---------|---------|
| [swift-markdown](https://github.com/swiftlang/swift-markdown) | Markdown parsing |
| [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) | Snapshot tests |
| [Highlightr](https://github.com/raspu/Highlightr) | Syntax highlighting (optional) |

## License

MIT. See [LICENSE](LICENSE).
