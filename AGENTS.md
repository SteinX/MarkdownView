# PROJECT KNOWLEDGE BASE

**Generated:** 2026-03-15
**Commit:** 2e1863b
**Branch:** main

## OVERVIEW

iOS Markdown rendering library with UITextView-based rich attachments (tables, code blocks, images, quotes) and streaming mode for chat-style AI assistant UIs. Uses UIKit (not SwiftUI). Distributed as SPM package + pre-built XCFramework.

## STRUCTURE

```
ios-markdown-demo/
├── STXMarkdownView/              # SPM library (core rendering)
│   ├── Sources/STXMarkdownView/
│   │   ├── Core/                 # MarkdownView, Parser, Renderer, TextKit1
│   │   ├── Views/                # CodeBlock, Table, Quote, Image, HR
│   │   ├── Theme/                # Theming system
│   │   ├── Image/                # ImageCache (2-tier), async loading
│   │   └── Utils/                # AttachmentPool, ContentKey, CodeBlockAnalyzer, Logger, TableSizeCache
│   └── Tests/
│       ├── Core/                 # Parser tests (3 files: InlineParser, MarkdownParser, MarkdownRenderer)
│       ├── Views/                # View unit tests (4 files)
│       ├── Utils/                # AttachmentPool, ContentKey, Cache tests (6 files)
│       ├── Theme/                # Theme tests
│       ├── Integration/          # Full render pipeline + streaming invariants (4 files)
│       ├── Performance/          # Streaming benchmarks + memory/hitch profiling (3 files, 3000+ lines)
│       ├── Snapshot/             # Visual regression (library-level)
│       └── Helpers/              # Test utilities
├── MarkdownDemo/                 # UIKit demo app
│   ├── ViewController.swift      # Chat UI (UITableView + ChatBubbleCell)
│   ├── StreamingDemoViewController.swift  # Single-view streaming demo
│   ├── StreamingSimulator.swift  # Incremental text feeding (1-3 chars/tick)
│   └── ChatBubbleCell.swift      # Bubble cell with MarkdownView
├── MarkdownDemoSnapshotTests/    # App-level snapshot tests (headings, tables, dark mode, images)
├── MarkdownDemoUITests/          # UI performance tests (streaming hitch detection)
├── Frameworks/                   # Pre-built XCFramework output (Git LFS)
├── build/                        # Dynamic build mirror (for xcframework)
├── scripts/
│   ├── run-tests.sh              # Unit tests via xcodebuild
│   ├── run-snapshot-tests.sh     # Snapshot tests (--record for baselines)
│   └── build-xcframework.sh      # Static/dynamic XCFramework build
├── .github/workflows/
│   ├── pr-tests.yml              # CI: macOS 15, tests + SwiftLint
│   └── create-release.yml        # Release: test → build XCFramework on macOS 14/Xcode 15.4
├── .swiftlint.yml                # Scoped to Sources + MarkdownDemo
├── .gitattributes                # Git LFS for Frameworks/** and __Snapshots__/**/*.png
└── Package.swift                 # Root SPM manifest (swift-tools-version 5.9, iOS 15+)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| **Add markdown element** | Core/MarkdownParser.swift | Add `visit*` method, handle attachment via pool |
| **Custom view attachment** | Views/ | Implement view + Reusable + ContentKey + pool support |
| **Theme customization** | Theme/MarkdownTheme.swift | Sub-themes for code, quote, list, table, image |
| **Streaming behavior** | Core/MarkdownView.swift | `isStreaming`, `throttleInterval`, throttle timer, incremental textStorage |
| **Attachment pooling** | Utils/AttachmentPool.swift | Content-keyed reuse, streaming pool, LRU eviction |
| **Table size caching** | Utils/TableCellSizeCache.swift | 4-layer LRU cache (intrinsic, height, layout, cellParse) |
| **Layout bugs** | Core/MarkdownTextView.swift | TextKit1 attachment positioning via glyph rects |
| **Table rendering** | Views/MarkdownTableView.swift | 3-pass layout: intrinsic widths → compression → row heights |
| **Image loading** | Image/ImageCache.swift | Two-tier (NSCache + disk), CGImageSource downsampling |
| **Code block streaming** | Utils/CodeBlockAnalyzer.swift | Detects unclosed fences, skips highlighting on incomplete blocks |
| **Logging/debugging** | Utils/MarkdownLogger.swift | `subsystem:com.stx.markdown`, categories per module |
| **Demo app** | MarkdownDemo/ViewController.swift | Chat UITableView + streaming simulator |
| **Performance instrumentation** | Core/MarkdownView.swift | `RenderPipelineStats`, `OSSignposter`, `isRenderPipelineStatsEnabled` |
| **Performance tests** | Tests/Performance/ | StreamingPerformanceTests (2300+ lines), DisplayPipelineHitchTests, MemoryFootprintTests |

## ARCHITECTURE

```
MarkdownView (UIView, public entry point)
    └── MarkdownTextView (UITextView, TextKit1)
            ├── NSAttributedString (inline text, styled by theme)
            └── attachmentViews [Int: AttachmentInfo]
                    ├── CodeBlockView (Highlightr optional, scrollable)
                    ├── MarkdownTableView (UICollectionView, adaptive/scroll)
                    ├── QuoteView (nested MarkdownTextView, recursive)
                    ├── MarkdownImageView (async cache, downsampled)
                    └── HorizontalRuleView
```

**Data Flow:**
1. `MarkdownView.markdown = text` triggers render (throttled if streaming)
2. `MarkdownRenderer` coordinates: parses AST via swift-markdown, creates `MarkdownParser`
3. `MarkdownParser` (MarkupWalker) walks AST → builds NSAttributedString + attachment placeholders
4. Attachment views dequeued from `AttachmentPool` (content-keyed or streaming pool) or created new
5. `MarkdownTextView.layoutSubviews()` positions attachment views at glyph locations via layoutManager
6. Incremental update (O7): finds common prefix, replaces only changed tail in textStorage

**Streaming Pipeline:**
1. `isStreaming = true` → `scheduleThrottledRender()` with leading-edge timer
2. Trailing block view → streaming pool (type-based, single view per type, zero-cost reuse)
3. `CodeBlockAnalyzer` detects unclosed fences → skips syntax highlighting on last block
4. `isStreaming = false` → `finalizeStreamingRender()`, pool returns to content-keyed mode

## CONVENTIONS

- **TextKit1 forced** - Explicitly constructs NSLayoutManager/NSTextStorage in init to avoid TextKit2 warnings
- **Attachment reuse** - All attachment views implement `Reusable` protocol, pooled by `AttachmentContentKey`
- **Streaming pool** - Trailing block views go to type-based streaming pool for quick reuse
- **Width-first layout** - Set `preferredMaxLayoutWidth` BEFORE setting `markdown` for proper sizing
- **Optimization requires baseline** - All performance optimizations MUST include baseline tests (before/after metrics) to verify measurable improvement. If the optimization shows no significant gain, revert the optimization code — do not keep speculative changes. If the optimization touches multiple files or core components, it MUST be reviewed and approved by Oracle and Metis before merging into the codebase.
  - Baseline tests MUST use **streaming mode** as the benchmark scenario
  - Test content MUST be a sufficiently long and complex Markdown document covering all supported elements — especially nested/complex structures (tables within quotes, multi-language code blocks, deeply nested lists, images, horizontal rules, etc.)
  - To ensure stable and reproducible results, before/after benchmark runs MUST be performed on the **same device** in the same conditions
  - All optimization changes MUST pass existing functional tests with **zero regressions** — performance gains that break correctness are not acceptable
- **Agent asset portability** - Store project-level agent skills/workflows under `.agents/` (for example `.agents/skills/...`) instead of tool-specific directories such as `.opencode/`.

## ANTI-PATTERNS

- **NEVER use TextKit2** - Forces TextKit1 via explicit NSLayoutManager construction
- **NEVER set markdown without width** - Causes layout failures; always set `preferredMaxLayoutWidth` first in cells
- **NEVER hold strong refs to pooled views** - Pool manages lifecycle; views recycled between renders
- **NEVER create attachment view without pool check** - Always try `pool.dequeue()` first
- **NEVER skip `prepareForReuse()`** - Must reset state for pool recycling

## UNIQUE STYLES

- Chinese comments in some files (e.g., ChatBubbleCell.swift) — acceptable
- Attachment views use `#if canImport(Highlightr)` for optional syntax highlighting
- Logging via `MarkdownLogger` with subsystem filtering (Console.app: `subsystem:com.stx.markdown`)
- SwiftLint disables length/cyclomatic/identifier rules — see `.swiftlint.yml`

## DEPENDENCIES

| Package | Purpose |
|---------|---------|
| swift-markdown (0.7.3+) | Markdown AST parsing |
| swift-snapshot-testing (1.12.0+) | Visual regression tests |
| Highlightr (optional) | Syntax highlighting for code blocks |

## COMMANDS

```bash
# Run unit tests
./scripts/run-tests.sh

# Run snapshot tests (verify mode — requires baselines to exist)
./scripts/run-snapshot-tests.sh

# Run snapshot tests with recording (regenerate baselines)
./scripts/run-snapshot-tests.sh --record            # app-level (MarkdownDemoSnapshotTests)
./scripts/run-snapshot-tests.sh --record --library   # library-level (MarkdownViewSnapshotTests)

# Build XCFramework (static + dynamic)
./scripts/build-xcframework.sh

# Build via Xcode
open MarkdownDemo.xcodeproj
# Cmd+R to run demo
```

## NOTES

- Demo uses UITableView with `automaticDimension` row height — `MarkdownView.intrinsicContentSize` drives sizing
- Demo has two tabs: chat view (ViewController) and streaming demo (StreamingDemoViewController)
- Streaming mode coalesces rapid updates via throttle timer (default 100ms)
- `CodeBlockAnalyzer` detects unclosed fences during streaming to skip highlighting on incomplete blocks
- Memory pressure triggers 50% pool eviction via `UIApplication.didReceiveMemoryWarningNotification`
- `AttachmentPool.maxPoolSize` adapts to device RAM: <4GB→50, 4-8GB→100, >8GB→200
- `TableCellSizeCache` has 4 independent caches (intrinsic/height/layout/cellParse) with LRU eviction
- `ImageCache` uses CGImageSource downsampling to reduce memory; two-tier (memory + disk) with adaptive limits
- CI runs on macOS 15 (PR tests) and macOS 14 + Xcode 15.4 (release builds)
- Git LFS tracks Frameworks/** (XCFramework binaries) and **/__Snapshots__/**/*.png (snapshot baselines)

## SNAPSHOT TESTING

Two test targets with snapshot tests:
- **App-level** (`MarkdownDemoSnapshotTests`): full layout tests with UIGraphicsImageRenderer, run via `./scripts/run-snapshot-tests.sh`
- **Library-level** (`MarkdownViewSnapshotTests`): SPM target tests using swift-snapshot-testing, run via `./scripts/run-snapshot-tests.sh --library`

Both targets use the `SNAPSHOT_RECORDING` environment variable to control recording mode:
- Code: `isRecording = ProcessInfo.processInfo.environment["SNAPSHOT_RECORDING"] == "1"`
- **NEVER** hardcode `isRecording = true/false` in test source — always use the env var

Recording baselines (MUST do when adding new snapshot tests):
```bash
./scripts/run-snapshot-tests.sh --record              # app-level baselines
./scripts/run-snapshot-tests.sh --record --library     # library-level baselines
```

Verify mode (CI / normal runs):
```bash
./scripts/run-snapshot-tests.sh                        # app-level verify
./scripts/run-snapshot-tests.sh --library              # library-level verify
```

Workflow for adding new snapshot tests:
1. Write test methods
2. Record baselines: `--record` (app) or `--record --library` (library)
3. Verify: re-run without `--record` — all tests must pass
4. Commit both test code AND generated baseline images under `__Snapshots__/`

## Learning rule

When discovering a reusable insight, propose an update to `AGENTS.md` or a portable project-level skill under `.agents/skills/`.

Examples:

- architecture decisions
- coding conventions
- recurring bugs
- environment limitations
