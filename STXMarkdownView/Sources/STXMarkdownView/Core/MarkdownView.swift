import UIKit
import Markdown
import os

/// A UITextView subclass that renders Markdown content with custom attachments.
/// This is the main entry point for displaying Markdown in your UI.
/// Extends MarkdownTextView to inherit attachment layout handling.
open class MarkdownView: MarkdownTextView {
    private static let widthEpsilon: CGFloat = 0.5

    public struct RenderPipelineStats {
        public let markdownAssignments: Int
        public let streamingSchedules: Int
        public let throttledExecutes: Int
        public let renderCalls: Int
        public let renderSkips: Int
        public let widthUnavailable: Int

        public static let zero = RenderPipelineStats(
            markdownAssignments: 0,
            streamingSchedules: 0,
            throttledExecutes: 0,
            renderCalls: 0,
            renderSkips: 0,
            widthUnavailable: 0
        )
    }

    private final class RenderPipelineStatsCollector {
        private var stats = RenderPipelineStats.zero

        func snapshot(isEnabled: Bool) -> RenderPipelineStats {
            isEnabled ? stats : .zero
        }

        func reset() {
            stats = .zero
        }

        func markMarkdownAssignment(isEnabled: Bool) {
            guard isEnabled else { return }
            stats = RenderPipelineStats(
                markdownAssignments: stats.markdownAssignments &+ 1,
                streamingSchedules: stats.streamingSchedules,
                throttledExecutes: stats.throttledExecutes,
                renderCalls: stats.renderCalls,
                renderSkips: stats.renderSkips,
                widthUnavailable: stats.widthUnavailable
            )
        }

        func markStreamingSchedule(isEnabled: Bool) {
            guard isEnabled else { return }
            stats = RenderPipelineStats(
                markdownAssignments: stats.markdownAssignments,
                streamingSchedules: stats.streamingSchedules &+ 1,
                throttledExecutes: stats.throttledExecutes,
                renderCalls: stats.renderCalls,
                renderSkips: stats.renderSkips,
                widthUnavailable: stats.widthUnavailable
            )
        }

        func markThrottledExecute(isEnabled: Bool) {
            guard isEnabled else { return }
            stats = RenderPipelineStats(
                markdownAssignments: stats.markdownAssignments,
                streamingSchedules: stats.streamingSchedules,
                throttledExecutes: stats.throttledExecutes &+ 1,
                renderCalls: stats.renderCalls,
                renderSkips: stats.renderSkips,
                widthUnavailable: stats.widthUnavailable
            )
        }

        func markRenderCall(isEnabled: Bool) {
            guard isEnabled else { return }
            stats = RenderPipelineStats(
                markdownAssignments: stats.markdownAssignments,
                streamingSchedules: stats.streamingSchedules,
                throttledExecutes: stats.throttledExecutes,
                renderCalls: stats.renderCalls &+ 1,
                renderSkips: stats.renderSkips,
                widthUnavailable: stats.widthUnavailable
            )
        }

        func markRenderSkip(isEnabled: Bool) {
            guard isEnabled else { return }
            stats = RenderPipelineStats(
                markdownAssignments: stats.markdownAssignments,
                streamingSchedules: stats.streamingSchedules,
                throttledExecutes: stats.throttledExecutes,
                renderCalls: stats.renderCalls,
                renderSkips: stats.renderSkips &+ 1,
                widthUnavailable: stats.widthUnavailable
            )
        }

        func markWidthUnavailable(isEnabled: Bool) {
            guard isEnabled else { return }
            stats = RenderPipelineStats(
                markdownAssignments: stats.markdownAssignments,
                streamingSchedules: stats.streamingSchedules,
                throttledExecutes: stats.throttledExecutes,
                renderCalls: stats.renderCalls,
                renderSkips: stats.renderSkips,
                widthUnavailable: stats.widthUnavailable &+ 1
            )
        }
    }
    
    // MARK: - Configuration
    
    private static let renderSignposter = OSSignposter(
        subsystem: "com.stx.markdown", category: "Rendering"
    )
    
    public var theme: MarkdownTheme = .default {
        didSet {
            invalidateRenderInputCache()
            renderIfReady()
        }
    }
    
    public var imageHandler: MarkdownImageHandler = DefaultImageHandler() {
        didSet {
            invalidateRenderInputCache()
            renderIfReady()
        }
    }
    
    /// Enable streaming mode to throttle render updates and reduce CPU usage
    public var isStreaming: Bool = false {
        didSet {
            MarkdownLogger.info(.streaming, "streaming state changed -> \(isStreaming)")
            _attachmentPool.logStats(context: "streaming toggle")
            if !isStreaming && oldValue {
                finalizeStreamingRender()
            }
        }
    }
    
    /// Throttle interval for streaming mode (default 100ms = 10 renders/sec)
    public var throttleInterval: TimeInterval = 0.1

    public var isRenderPipelineStatsEnabled: Bool = false
    
    public var markdown: String = "" {
        didSet {
            statsCollector.markMarkdownAssignment(isEnabled: isRenderPipelineStatsEnabled)
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
    private var renderInputVersion: Int = 0
    private var lastRenderedInputVersion: Int = -1
    
    // Streaming throttle state
    private var pendingMarkdown: String?
    private var throttleTimer: Timer?
    private var throttleWindowDeadline: CFTimeInterval = 0
    private let statsCollector = RenderPipelineStatsCollector()
    
    // Intrinsic size cache: avoids ensureLayout during UITableView batch updates for stable cells
    private var cachedIntrinsicSize: CGSize?
    private var cachedIntrinsicSizeContainerWidth: CGFloat = -1
    
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
        let containerWidth = textContainer.size.width
        if let cached = cachedIntrinsicSize,
           abs(containerWidth - cachedIntrinsicSizeContainerWidth) <= Self.widthEpsilon {
            return cached
        }
        layoutManager.ensureLayout(for: textContainer)
        let size = layoutManager.usedRect(for: textContainer).size
        let insets = textContainerInset
        let finalSize = CGSize(width: ceil(size.width + insets.left + insets.right), 
                      height: ceil(size.height + insets.top + insets.bottom + 1))
        cachedIntrinsicSize = finalSize
        cachedIntrinsicSizeContainerWidth = containerWidth
        return finalSize
    }
    
    // MARK: - Rendering
    
    /// Attempts to render immediately if we have a valid width
    private func renderIfReady() {
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        
        if width > 0 {
            render(with: width)
        } else {
            statsCollector.markWidthUnavailable(isEnabled: isRenderPipelineStatsEnabled)
            // No width available, mark for later render in layoutSubviews
            setNeedsLayout()
        }
    }
    
    open override func layoutSubviews() {
        applyPreferredTextContainerWidth()

        // Check if we need to render (e.g., width wasn't available before)
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        
        if width > 0 && !markdown.isEmpty {
            let widthChanged = abs(width - lastRenderedWidth) > Self.widthEpsilon
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
        statsCollector.markRenderCall(isEnabled: isRenderPipelineStatsEnabled)
        // O5: Skip render if markdown content is identical to last render at same width
        if markdown == lastRenderedMarkdown,
           abs(width - lastRenderedWidth) <= Self.widthEpsilon,
           renderInputVersion == lastRenderedInputVersion {
            statsCollector.markRenderSkip(isEnabled: isRenderPipelineStatsEnabled)
            return
        }
        lastRenderedWidth = width
        
        let signpostID = Self.renderSignposter.makeSignpostID()
        let signpostState = Self.renderSignposter.beginInterval("Render", id: signpostID)
        defer { Self.renderSignposter.endInterval("Render", signpostState) }
        
        MarkdownLogger.info(.view, "render started, width=\(Int(width)), streaming=\(isStreaming)")
        
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
            cachedIntrinsicSize = nil
            invalidateIntrinsicContentSize()
            return
        }
        
        let codeBlockState: CodeBlockAnalyzer.CodeBlockState? = isStreaming ? CodeBlockAnalyzer.analyze(markdown) : nil
        
        let renderer = MarkdownRenderer(theme: theme, imageHandler: imageHandler, maxLayoutWidth: width, tableSizeCache: tableSizeCache)
        
        // Phase 1: Parse
        let result: RenderedMarkdown
        if let document = cachedDocument {
            result = renderer.render(document, attachmentPool: _attachmentPool, codeBlockState: codeBlockState, isStreaming: isStreaming)
        } else {
            let document = renderer.parse(markdown)
            cachedDocument = document
            result = renderer.render(document, attachmentPool: _attachmentPool, codeBlockState: codeBlockState, isStreaming: isStreaming)
        }
        
        // Phase 3: O6 Diff
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
        
        // Phase 4: O7 Incremental TextStorage update
        var incrementalChangeStart: Int?
        if let previous = previousRenderedString {
            let newString = result.attributedString
            let commonPrefix = findCommonPrefixLength(previous, newString)
            let oldLen = previous.length
            let newLen = newString.length
            
            if commonPrefix == oldLen && commonPrefix == newLen {
                // Content identical
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
        lastRenderedInputVersion = renderInputVersion
        
        // Phase 5: Layout + intrinsic size computation + attachment assignment
        
        if let changeStart = incrementalChangeStart {
            let changedRange = NSRange(location: changeStart, length: textStorage.length - changeStart)
            layoutManager.invalidateLayout(forCharacterRange: changedRange, actualCharacterRange: nil)
        } else {
            layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
        }
        layoutManager.ensureLayout(for: textContainer)
        markAttachmentLayoutEnsured(forWidth: width)
        
        attachmentViews = finalAttachments
        if let changeStart = incrementalChangeStart {
            setNeedsAttachmentLayout(fromCharacterIndex: changeStart)
            markAttachmentLayoutEnsured(forWidth: width)
        }
        lastRenderedResult = RenderedMarkdown(attributedString: result.attributedString, attachments: finalAttachments)
        _attachmentPool.logStats(context: "after render")
        
        let maxPoolRetention = max(finalAttachments.count * 2, 10)
        _attachmentPool.trimToSize(maxPoolRetention)
        
        let usedSize = layoutManager.usedRect(for: textContainer).size
        let insets = textContainerInset
        let newHeight = ceil(usedSize.height + insets.top + insets.bottom + 1)
        let newWidth = ceil(usedSize.width + insets.left + insets.right)
        let newICS = CGSize(width: newWidth, height: newHeight)
        
        let previousHeight = cachedIntrinsicSize?.height ?? -1
        cachedIntrinsicSize = newICS
        cachedIntrinsicSizeContainerWidth = textContainer.size.width
        
        if isStreaming {
            if abs(newHeight - previousHeight) > 0.5 {
                invalidateIntrinsicContentSize()
            }
        } else {
            invalidateIntrinsicContentSize()
        }
        
        MarkdownLogger.debug(.view, "render completed, attachments=\(result.attachments.count)")
    }

    private func invalidateRenderInputCache() {
        renderInputVersion &+= 1
    }
    
    // MARK: - Streaming Throttle
    
    private func scheduleThrottledRender(newMarkdown: String) {
        if pendingMarkdown == newMarkdown {
            return
        }

        if isRenderInputEquivalentForCurrentWidth(newMarkdown) {
            return
        }

        statsCollector.markStreamingSchedule(isEnabled: isRenderPipelineStatsEnabled)
        pendingMarkdown = newMarkdown

        if throttleTimer != nil {
            return
        }

        let now = CACurrentMediaTime()
        if now >= throttleWindowDeadline {
            executeThrottledRender()
            throttleWindowDeadline = CACurrentMediaTime() + throttleInterval
            return
        }

        let delay = throttleWindowDeadline - now
        if delay <= 0 {
            executeThrottledRender()
            throttleWindowDeadline = CACurrentMediaTime() + throttleInterval
            return
        }

        throttleTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.executeThrottledRender()
            self.throttleWindowDeadline = CACurrentMediaTime() + self.throttleInterval
        }
    }

    private func isRenderInputEquivalentForCurrentWidth(_ markdown: String) -> Bool {
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        guard width > 0 else { return false }

        return markdown == lastRenderedMarkdown
            && abs(width - lastRenderedWidth) <= Self.widthEpsilon
            && renderInputVersion == lastRenderedInputVersion
    }
    
    private func executeThrottledRender() {
        statsCollector.markThrottledExecute(isEnabled: isRenderPipelineStatsEnabled)
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
            // O9: Defer layout to parent's next pass instead of flushing immediately.
            // In UITableView, performBatchUpdates triggers layout after this returns;
            // flushing here would cause a redundant double-layout every tick.
            // ICS is already cached in Phase 5, so parent can query height without layout.
            setNeedsLayout()
        } else {
            statsCollector.markWidthUnavailable(isEnabled: isRenderPipelineStatsEnabled)
            setNeedsLayout()
        }
    }
    
    private func finalizeStreamingRender() {
        throttleTimer?.invalidate()
        throttleTimer = nil
        throttleWindowDeadline = 0
        
        if pendingMarkdown != nil {
            pendingMarkdown = nil
            cachedDocument = nil
            renderIfReady()
        } else {
            cachedIntrinsicSize = nil
            invalidateIntrinsicContentSize()
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
        if abs(textContainer.size.width - preferredMaxLayoutWidth) > Self.widthEpsilon
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

    public var renderPipelineStats: RenderPipelineStats {
        statsCollector.snapshot(isEnabled: isRenderPipelineStatsEnabled)
    }

    public func resetRenderPipelineStats() {
        statsCollector.reset()
    }
    
    /// Call this before reusing the view (e.g., in prepareForReuse)
    public override func cleanUp() {
        super.cleanUp()
        markdown = ""
        cachedDocument = nil
        lastRenderedWidth = 0
        lastRenderedMarkdown = nil
        previousRenderedString = nil
        cachedIntrinsicSize = nil
        
        throttleTimer?.invalidate()
        throttleTimer = nil
        pendingMarkdown = nil
        throttleWindowDeadline = 0
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
