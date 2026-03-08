# STXMarkdownView Library

SPM library for high-performance Markdown rendering in UITextView with rich attachment views.

## STRUCTURE

```
STXMarkdownView/
├── Sources/STXMarkdownView/
│   ├── Core/           # Main rendering pipeline
│   │   ├── MarkdownView.swift      # Public entry point (streaming, throttle, incremental update)
│   │   ├── MarkdownTextView.swift  # TextKit1 attachment positioning via glyph rects
│   │   ├── MarkdownParser.swift    # AST walker → NSAttributedString + attachments
│   │   └── MarkdownRenderer.swift  # Coordinates parse/render, append-only detection
│   ├── Views/          # Attachment view implementations
│   │   ├── CodeBlockView.swift     # Highlightr optional, header bar + copy, scrollable
│   │   ├── MarkdownTableView.swift # UICollectionView, 3-pass adaptive layout
│   │   ├── QuoteView.swift         # Left border + nested MarkdownTextView (recursive)
│   │   ├── MarkdownImageView.swift # Async cached loading, downsampled
│   │   └── HorizontalRuleView.swift
│   ├── Theme/          # MarkdownTheme + sub-themes (heading, code, quote, list, table, image)
│   ├── Image/          # ImageCache (2-tier NSCache+disk), MarkdownImageHandler protocol
│   └── Utils/
│       ├── AttachmentPool.swift       # Content-keyed + streaming pool, LRU, adaptive maxSize
│       ├── AttachmentContentKey.swift # Protocol + AttachmentInfo struct
│       ├── CodeBlockAnalyzer.swift    # Detects unclosed fences for streaming
│       ├── MarkdownLogger.swift       # os_log wrapper, subsystem:com.stx.markdown
│       └── TableCellSizeCache.swift   # 4-layer LRU (intrinsic/height/layout/cellParse)
└── Tests/
    ├── Core/           # MarkdownParser tests
    ├── Views/          # View unit tests (4 files)
    ├── Utils/          # Pool, ContentKey, Cache, Logger tests (6 files)
    ├── Theme/          # Theme configuration tests
    ├── Integration/    # Full render pipeline + streaming render tests
    ├── Performance/    # StreamingPerformanceTests (1400+ lines, benchmark baselines)
    ├── Snapshot/       # Visual regression (library-level)
    └── Helpers/        # Test utilities
```

## WHERE TO LOOK

| Task | File | Notes |
|------|------|-------|
| Parse new element | MarkdownParser.swift | Add `visit*` method |
| Attachment sizing | MarkdownTextView.swift:layoutSubviews | Glyph-based positioning, fallback to lineFragmentRect |
| View pooling | AttachmentPool.swift | Content-keyed dequeue/recycle, streaming pool |
| Theme extension | MarkdownTheme.swift | Add sub-struct, update `default` and `quoted` |
| Streaming behavior | MarkdownView.swift | Throttle timer, incremental textStorage (O7) |
| Table layout | MarkdownTableView.swift | 3-pass: intrinsic widths → compression → row heights |
| Table caching | TableCellSizeCache.swift | 4 independent caches, LRU eviction |
| Image pipeline | ImageCache.swift | 2-tier cache, CGImageSource downsampling |
| Code streaming | CodeBlockAnalyzer.swift | Unclosed fence detection, skip highlighting |
| Performance tests | Tests/Performance/ | Streaming benchmarks, 1400+ lines |

## CONVENTIONS

- **All attachment views** must implement `Reusable` + have matching `*ContentKey` struct
- **ContentKey** includes all factors affecting visual appearance (hash, width, isInsideQuote, etc.)
- **Pool dequeue** returns `(view, exactMatch)` — update view if `!exactMatch`
- **Streaming pool** — last block goes to type-based pool, not content-keyed
- **InlineParser** — separate simplified parser for table cell content (no block-level elements)
- **List markers** cycle: numeric → alpha → roman for nested ordered lists

## ANTI-PATTERNS

- **NEVER suppress Highlightr import** — Use `#if canImport(Highlightr)` pattern
- **NEVER create attachment view without pool check** — Always try `pool.dequeue()` first
- **NEVER skip `prepareForReuse()`** — Must reset state for pool recycling
- **NEVER use TextKit2** — MarkdownTextView explicitly constructs NSLayoutManager
- **NEVER call render without width** — Set `preferredMaxLayoutWidth` before `markdown`

## KEY PATTERNS

### Adding New Attachment Type

1. Create `MyView.swift` in Views/
2. Implement `Reusable` protocol
3. Create `MyContentKey: AttachmentContentKey`
4. Add `visit*` in MarkdownParser.swift:
   ```swift
   mutating func visitMyElement(_ element: MyElement) {
       let contentKey = MyContentKey(...)
       let view: MyView
       if let pool = attachmentPool,
          let (pooledView, exactMatch): (MyView, Bool) = pool.dequeue(...) {
           view = pooledView
           if !exactMatch { view.update(...) }
       } else {
           view = MyView(...)
       }
       insertAttachment(view: view, size: size, isBlock: true, contentKey: contentKey)
   }
   ```

### Streaming Mode Flow

1. `isStreaming = true` → renders throttled (100ms default)
2. Trailing attachment uses streaming pool (type-based, not content-keyed)
3. `isStreaming = false` → final render, pool returns to content-keyed mode
4. `CodeBlockAnalyzer` skips highlighting on unclosed code fences
5. O7 incremental update: finds common prefix, replaces only changed tail in textStorage
