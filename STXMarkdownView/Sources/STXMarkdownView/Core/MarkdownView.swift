import UIKit
import Markdown
import os

/// A UITextView subclass that renders Markdown content with custom attachments.
/// This is the main entry point for displaying Markdown in your UI.
/// Extends MarkdownTextView to inherit attachment layout handling.
open class MarkdownView: MarkdownTextView {
    
    // MARK: - Configuration
    
    private static let renderSignposter = OSSignposter(
        subsystem: "com.stx.markdown", category: "Rendering"
    )
    
    public var theme: MarkdownTheme = .default {
        didSet {
            renderIfReady()
        }
    }
    
    public var imageHandler: MarkdownImageHandler = DefaultImageHandler() {
        didSet {
            renderIfReady()
        }
    }
    
    /// Enable streaming mode to throttle render updates and reduce CPU usage
    public var isStreaming: Bool = false {
        didSet {
            MarkdownLogger.info(.streaming, "streaming state changed -> \(isStreaming)")
            _attachmentPool.logStats(context: "streaming toggle")
            if !isStreaming && oldValue {
                // Stream ended: cleanup timer and ensure final render
                finalizeStreamingRender()
            }
        }
    }
    
    /// Throttle interval for streaming mode (default 100ms = 10 renders/sec)
    public var throttleInterval: TimeInterval = 0.1
    
    public var markdown: String = "" {
        didSet {
            if isStreaming {
                // Streaming mode: throttle rendering
                scheduleThrottledRender(newMarkdown: markdown)
            } else {
                // Normal mode: render immediately
                cachedDocument = nil
                renderIfReady()
            }
        }
    }
    
    /// Manual width override for layout calculations.
    /// MUST be set before setting markdown for proper cell sizing.
    public var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet {
            applyPreferredTextContainerWidth()

            if preferredMaxLayoutWidth != oldValue, !markdown.isEmpty {
                // Re-render if markdown already set
                renderIfReady()
            }
        }
    }
    
    // MARK: - State
    
    private var lastRenderedWidth: CGFloat = 0
    private var cachedDocument: Document?
    private let _attachmentPool = AttachmentPool()
    private var lastRenderWasStreaming: Bool = false
    private let tableSizeCache = TableCellSizeCache()
    private var lastRenderedMarkdown: String?
    private var previousRenderedString: NSAttributedString?
    private(set) var lastRenderedResult: RenderedMarkdown?
    
    // Streaming throttle state
    private var pendingMarkdown: String?
    private var throttleTimer: Timer?
    
    // MARK: - Init
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public convenience init(theme: MarkdownTheme = .default) {
        self.init(frame: .zero, textContainer: nil)
        self.theme = theme
    }
    
    // MARK: - Layout
    
    open override var intrinsicContentSize: CGSize {
        layoutManager.ensureLayout(for: textContainer)
        let size = layoutManager.usedRect(for: textContainer).size
        let insets = textContainerInset
        let finalSize = CGSize(width: ceil(size.width + insets.left + insets.right), 
                      height: ceil(size.height + insets.top + insets.bottom + 1))
        return finalSize
    }
    
    // MARK: - Rendering
    
    /// Attempts to render immediately if we have a valid width
    private func renderIfReady() {
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        
        if width > 0 {
            render(with: width)
        } else {
            // No width available, mark for later render in layoutSubviews
            setNeedsLayout()
        }
    }
    
    open override func layoutSubviews() {
        applyPreferredTextContainerWidth()

        // Check if we need to render (e.g., width wasn't available before)
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        
        if width > 0 && !markdown.isEmpty {
            let widthChanged = abs(width - lastRenderedWidth) > CGFloat.ulpOfOne
            if widthChanged {
                render(with: width)
            }
        }

        applyPreferredTextContainerWidth()
        
        // Call super AFTER render so attachmentViews are set
        super.layoutSubviews()
        
        // Re-enforce the text container width if we have a preference, 
        // because super.layoutSubviews() might have reset it to bounds.width (which could be 0 during sizing)
        applyPreferredTextContainerWidth()
    }
    
    private func render(with width: CGFloat) {
        // O5: Skip render if markdown content is identical to last render at same width
        if markdown == lastRenderedMarkdown && abs(width - lastRenderedWidth) < CGFloat.ulpOfOne {
            return
        }
        lastRenderedWidth = width
        
        let signpostID = Self.renderSignposter.makeSignpostID()
        let signpostState = Self.renderSignposter.beginInterval("Render", id: signpostID)
        defer { Self.renderSignposter.endInterval("Render", signpostState) }
        
        MarkdownLogger.info(.view, "render started, width=\(Int(width)), streaming=\(isStreaming)")
        
        // Set text container width for correct intrinsic size calculation
        // IMPORTANT: Must set height to large value to allow layout manager to calculate used rect
        textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        
        let oldAttachments = attachmentViews
        let recycleToStreamingPool = lastRenderWasStreaming
        lastRenderWasStreaming = isStreaming
        _attachmentPool.logStats(context: "before render")
        
        if markdown.isEmpty {
            let maxPos = oldAttachments.keys.max() ?? -1
            for (pos, info) in oldAttachments {
                let isTrailing = recycleToStreamingPool && pos == maxPos
                _attachmentPool.recycle(info.view, anyKey: info.contentKey, isStreaming: isTrailing)
            }
            attachmentViews = [:]
            attributedText = nil
            previousRenderedString = nil
            lastRenderedMarkdown = markdown
            lastRenderedResult = nil
            invalidateIntrinsicContentSize()
            return
        }
        
        // Unclosed code fence detection only matters during streaming
        let codeBlockState: CodeBlockAnalyzer.CodeBlockState? = isStreaming ? CodeBlockAnalyzer.analyze(markdown) : nil
        
        let renderer = MarkdownRenderer(theme: theme, imageHandler: imageHandler, maxLayoutWidth: width, tableSizeCache: tableSizeCache)
        
        let result: RenderedMarkdown
        if let document = cachedDocument {
            // Reuse cached AST
            result = renderer.render(document, attachmentPool: _attachmentPool, codeBlockState: codeBlockState, isStreaming: isStreaming)
        } else {
            // Parse and cache
            let document = renderer.parse(markdown)
            cachedDocument = document
            result = renderer.render(document, attachmentPool: _attachmentPool, codeBlockState: codeBlockState, isStreaming: isStreaming)
        }
        
        // Diff: preserve views whose contentKey matches between old and new renders
        var finalAttachments = result.attachments
        var oldByKey: [AnyHashable: [(position: Int, info: AttachmentInfo)]] = [:]
        for (pos, info) in oldAttachments {
            oldByKey[info.contentKey, default: []].append((position: pos, info: info))
        }
        
        var preservedOldViewIDs = Set<ObjectIdentifier>()
        for (newPos, newInfo) in result.attachments {
            if var entries = oldByKey[newInfo.contentKey], !entries.isEmpty {
                let old = entries.removeFirst()
                oldByKey[newInfo.contentKey] = entries.isEmpty ? nil : entries
                finalAttachments[newPos] = AttachmentInfo(
                    view: old.info.view, contentKey: old.info.contentKey, charPosition: newPos
                )
                preservedOldViewIDs.insert(ObjectIdentifier(old.info.view))
                _attachmentPool.recycle(newInfo.view, anyKey: newInfo.contentKey, isStreaming: false)
            }
        }
        
        let maxOldPos = oldAttachments.keys.max() ?? -1
        for entries in oldByKey.values {
            for entry in entries {
                let isTrailing = recycleToStreamingPool && entry.position == maxOldPos
                _attachmentPool.recycle(entry.info.view, anyKey: entry.info.contentKey, isStreaming: isTrailing)
            }
        }
        
        // O7: Incremental TextStorage update
        // Use direct textStorage editing with scoped change range instead of full attributedText
        // replacement, which triggers heavy UITextView bookkeeping and full-document layout invalidation.
        var incrementalChangeStart: Int?
        if let previous = previousRenderedString {
            let newString = result.attributedString
            let commonPrefix = findCommonPrefixLength(previous, newString)
            let oldLen = previous.length
            let newLen = newString.length
            
            if commonPrefix == oldLen && commonPrefix == newLen {
                // Content identical, no update needed
            } else {
                textStorage.beginEditing()
                let replaceRange = NSRange(location: commonPrefix, length: oldLen - commonPrefix)
                if commonPrefix < newLen {
                    let tail = newString.attributedSubstring(from: NSRange(location: commonPrefix, length: newLen - commonPrefix))
                    textStorage.replaceCharacters(in: replaceRange, with: tail)
                } else {
                    textStorage.deleteCharacters(in: replaceRange)
                }
                textStorage.endEditing()
                incrementalChangeStart = commonPrefix
            }
        } else {
            attributedText = result.attributedString
        }
        previousRenderedString = result.attributedString
        lastRenderedMarkdown = markdown
        
        // O6+O7: Scoped layout invalidation
        // During streaming, skip entirely — layoutIfNeeded() in executeThrottledRender() handles it.
        // For non-streaming with incremental update, only invalidate from the change point forward.
        // For non-streaming with full replacement (first render), invalidate entire range.
        if !isStreaming {
            if let changeStart = incrementalChangeStart {
                let changedRange = NSRange(location: changeStart, length: textStorage.length - changeStart)
                layoutManager.invalidateLayout(forCharacterRange: changedRange, actualCharacterRange: nil)
                layoutManager.ensureLayout(for: textContainer)
            } else {
                layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
                layoutManager.ensureLayout(for: textContainer)
            }
        }
        
        attachmentViews = finalAttachments
        lastRenderedResult = RenderedMarkdown(attributedString: result.attributedString, attachments: finalAttachments)
        _attachmentPool.logStats(context: "after render")
        
        let maxPoolRetention = max(finalAttachments.count * 2, 10)
        _attachmentPool.trimToSize(maxPoolRetention)
        
        // Force intrinsic size recalculation
        invalidateIntrinsicContentSize()
        
        MarkdownLogger.debug(.view, "render completed, attachments=\(result.attachments.count)")
    }
    
    // MARK: - Streaming Throttle
    
    private func scheduleThrottledRender(newMarkdown: String) {
        // Save latest pending content
        pendingMarkdown = newMarkdown
        
        // If timer already running, wait for it to trigger (don't create new one)
        guard throttleTimer == nil else { return }
        
        // Leading edge: render immediately on first update, then throttle subsequent
        executeThrottledRender()
        
        throttleTimer = Timer.scheduledTimer(
            withTimeInterval: throttleInterval,
            repeats: false
        ) { [weak self] _ in
            self?.executeThrottledRender()
        }
    }
    
    private func executeThrottledRender() {
        guard pendingMarkdown != nil else {
            throttleTimer = nil
            return
        }
        
        // Clear pending content and timer
        pendingMarkdown = nil
        throttleTimer = nil
        
        // Execute render
        cachedDocument = nil
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        if width > 0 {
            render(with: width)
            // Flush layout immediately: render() leaves attachment views at (0,0) until
            // the next vsync; skipping this causes images to float during streaming.
            layoutIfNeeded()
        } else {
            setNeedsLayout()
        }
    }
    
    private func finalizeStreamingRender() {
        // Cancel pending timer
        throttleTimer?.invalidate()
        throttleTimer = nil
        
        // If there's unrendered content, render it immediately
        if pendingMarkdown != nil {
            pendingMarkdown = nil
            cachedDocument = nil
            renderIfReady()
        }
    }

    open override func restoreTextContainerConfiguration() {
        applyPreferredTextContainerWidth()
    }

    private func applyPreferredTextContainerWidth() {
        guard preferredMaxLayoutWidth > 0 else {
            textContainer.widthTracksTextView = true
            return
        }

        textContainer.widthTracksTextView = false
        if abs(textContainer.size.width - preferredMaxLayoutWidth) > CGFloat.ulpOfOne
            || textContainer.size.height < .greatestFiniteMagnitude {
            textContainer.size = CGSize(width: preferredMaxLayoutWidth, height: .greatestFiniteMagnitude)
        }
    }
    
    // MARK: - Cleanup
    
    func findCommonPrefixLength(_ a: NSAttributedString, _ b: NSAttributedString) -> Int {
        let minLen = min(a.length, b.length)
        guard minLen > 0 else { return 0 }
        
        let aStr = a.string as NSString
        let bStr = b.string as NSString
        
        var textPrefixLen = 0
        while textPrefixLen < minLen && aStr.character(at: textPrefixLen) == bStr.character(at: textPrefixLen) {
            textPrefixLen += 1
        }
        guard textPrefixLen > 0 else { return 0 }
        
        // Walk attribute runs to find first divergence within the text prefix.
        // Each attributes(at:effectiveRange:) returns the full run, so this is O(runs) not O(chars).
        var pos = 0
        while pos < textPrefixLen {
            var aRange = NSRange()
            var bRange = NSRange()
            let aAttrs = a.attributes(at: pos, effectiveRange: &aRange)
            let bAttrs = b.attributes(at: pos, effectiveRange: &bRange)
            
            if !NSDictionary(dictionary: aAttrs).isEqual(to: bAttrs) {
                return pos
            }
            
            let aRunEnd = min(aRange.location + aRange.length, textPrefixLen)
            let bRunEnd = min(bRange.location + bRange.length, textPrefixLen)
            pos = min(aRunEnd, bRunEnd)
        }
        
        return textPrefixLen
    }
    
    /// Call this before reusing the view (e.g., in prepareForReuse)
    public override func cleanUp() {
        super.cleanUp()
        markdown = ""
        cachedDocument = nil
        lastRenderedWidth = 0
        lastRenderedMarkdown = nil
        previousRenderedString = nil
        
        throttleTimer?.invalidate()
        throttleTimer = nil
        pendingMarkdown = nil
        lastRenderWasStreaming = false
        
        tableSizeCache.clearAll()
        _attachmentPool.trimToSize(0)
    }

}

// MARK: - Logging Configuration

extension MarkdownView {
    /// 全局日志级别配置
    /// 默认为 .off (关闭)
    /// 设置为 .debug 可启用性能计时
    public static var logLevel: MarkdownLogLevel {
        get { MarkdownLogger.level }
        set { MarkdownLogger.level = newValue }
    }
}
