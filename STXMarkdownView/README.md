# STXMarkdownView

STXMarkdownView is a fast Markdown rendering UITextView with rich attachments for tables, code blocks,
images, and block quotes. It is built on Swift-Markdown and supports streaming updates for chat-style
UI.

## Features

- Swift-Markdown parsing
- UITextView-based rendering with attachment reuse
- Code blocks with optional syntax highlighting (Highlightr)
- Tables with adaptive or scrollable layout
- Block quotes with nested rendering
- Images with memory + disk caching
- Streaming mode with throttled rendering

## Requirements

- iOS 15.0+
- Swift 5.9+

## Installation

### Swift Package Manager

Add the package in Xcode or use `Package.swift`:

```swift
.package(url: "https://github.com/your-org/STXMarkdownView.git", from: "1.0.0")
```

Then add `STXMarkdownView` to your target dependencies.

### CocoaPods

```ruby
pod 'STXMarkdownView', '~> 1.0.0'
```

To enable syntax highlighting with Highlightr:

```ruby
pod 'STXMarkdownView/SyntaxHighlighting', '~> 1.0.0'
```

## Usage

```swift
import STXMarkdownView

let markdownView = MarkdownView()
markdownView.theme = .default
markdownView.markdown = """
# Hello Markdown

This is **bold** text and `inline code`.
"""
```

### Streaming Mode

```swift
markdownView.isStreaming = true
markdownView.throttleInterval = 0.1
markdownView.markdown = "partial markdown..."
```

When streaming ends:

```swift
markdownView.isStreaming = false
```

## Theme Customization

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

## Optional Syntax Highlighting

STXMarkdownView uses Highlightr when available. The code automatically falls back to plain text if the
module is not present.

For Swift Package Manager, add Highlightr to your app target and it will be picked up automatically.

## License

MIT. See `LICENSE`.
