import UIKit
import Markdown

/// A UITextView subclass that renders Markdown content with custom attachments.
/// This is the main entry point for displaying Markdown in your UI.
/// Extends MarkdownTextView to inherit attachment layout handling.
open class MarkdownView: MarkdownTextView {
    
    // MARK: - Configuration
    
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
            if preferredMaxLayoutWidth != oldValue {
                if preferredMaxLayoutWidth > 0 {
                    // Disable automatic width tracking so our manual width isn't overwritten
                    textContainer.widthTracksTextView = false
                    textContainer.size.width = preferredMaxLayoutWidth
                } else {
                    // Re-enable automatic tracking for auto-layout resizing
                    textContainer.widthTracksTextView = true
                }
                
                // Re-render if markdown already set
                if !markdown.isEmpty {
                    renderIfReady()
                }
            }
        }
    }
    
    // MARK: - State
    
    private var lastRenderedWidth: CGFloat = 0
    private var cachedDocument: Document?
    private let _attachmentPool = AttachmentPool()
    private var lastRenderWasStreaming: Bool = false
    private let tableSizeCache = TableCellSizeCache()
    
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
        // Check if we need to render (e.g., width wasn't available before)
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        
        if width > 0 && !markdown.isEmpty {
            let widthChanged = abs(width - lastRenderedWidth) > CGFloat.ulpOfOne
            if widthChanged {
                render(with: width)
            }
        }

        if preferredMaxLayoutWidth > 0 {
            textContainer.size = CGSize(width: preferredMaxLayoutWidth, height: .greatestFiniteMagnitude)
        }
        
        // Call super AFTER render so attachmentViews are set
        super.layoutSubviews()
        
        // Re-enforce the text container width if we have a preference, 
        // because super.layoutSubviews() might have reset it to bounds.width (which could be 0 during sizing)
        if preferredMaxLayoutWidth > 0 && abs(textContainer.size.width - preferredMaxLayoutWidth) > 0.1 {
             textContainer.size.width = preferredMaxLayoutWidth
        }
    }
    
    private func render(with width: CGFloat) {
            lastRenderedWidth = width
        
        MarkdownLogger.info(.view, "render started, width=\(Int(width)), streaming=\(isStreaming)")
        
        // Set text container width for correct intrinsic size calculation
        // IMPORTANT: Must set height to large value to allow layout manager to calculate used rect
        textContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
        
        // Recycle old attachments back to pool
        if !attachmentViews.isEmpty {
            MarkdownLogger.debug(.pool, "recycle attachments count=\(attachmentViews.count)")
        }
        let recycleToStreamingPool = lastRenderWasStreaming
        lastRenderWasStreaming = isStreaming
        _attachmentPool.logStats(context: "before recycle")

        let maxPosition = attachmentViews.keys.max() ?? -1
        attachmentViews.forEach { position, info in
            let isTrailing = recycleToStreamingPool && position == maxPosition

            info.view.removeFromSuperview()
            _attachmentPool.recycle(info.view, anyKey: info.contentKey, isStreaming: isTrailing)
        }
        attachmentViews.removeAll()
        _attachmentPool.logStats(context: "after recycle")
        
        if markdown.isEmpty {
            attributedText = nil
            invalidateIntrinsicContentSize()
            return
        }
        
        // Analyze markdown for unclosed code blocks (for smart highlighting)
        let codeBlockState = CodeBlockAnalyzer.analyze(markdown)
        
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
        
        attributedText = result.attributedString
        
        // Force TextKit to invalidate and recalculate layout immediately
        // This is crucial after cell reuse to avoid stale glyph positions
        layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
        layoutManager.ensureLayout(for: textContainer)
        
        attachmentViews = result.attachments
        _attachmentPool.logStats(context: "after render")
        
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
        
        // Create throttle timer
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
    
    // MARK: - Cleanup
    
    /// Call this before reusing the view (e.g., in prepareForReuse)
    public override func cleanUp() {
        super.cleanUp()
        markdown = ""
        cachedDocument = nil
        lastRenderedWidth = 0
        
        // Clean up throttle state
        throttleTimer?.invalidate()
        throttleTimer = nil
        pendingMarkdown = nil
        lastRenderWasStreaming = false
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
