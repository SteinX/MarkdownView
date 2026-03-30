import UIKit
import Markdown
import os

open class MarkdownView: MarkdownTextView {
    private static let widthEpsilon: CGFloat = 0.5

    public struct RenderPipelineStats {
        public let markdownAssignments: Int
        public let streamingSchedules: Int
        public let throttledExecutes: Int
        public let renderCalls: Int
        public let renderSkips: Int
        public let widthUnavailable: Int
        public let attachmentCreated: Int
        public let attachmentPreserved: Int
        public let attachmentRecycled: Int
        public let incrementalUpdates: Int
        public let fullInvalidations: Int
        public let layoutSubviewsCalls: Int
        public let tableFullLayoutPasses: Int

        public static let zero = RenderPipelineStats(
            markdownAssignments: 0,
            streamingSchedules: 0,
            throttledExecutes: 0,
            renderCalls: 0,
            renderSkips: 0,
            widthUnavailable: 0,
            attachmentCreated: 0,
            attachmentPreserved: 0,
            attachmentRecycled: 0,
            incrementalUpdates: 0,
            fullInvalidations: 0,
            layoutSubviewsCalls: 0,
            tableFullLayoutPasses: 0
        )
    }

    private final class RenderPipelineStatsCollector {
        private var _markdownAssignments = 0
        private var _streamingSchedules = 0
        private var _throttledExecutes = 0
        private var _renderCalls = 0
        private var _renderSkips = 0
        private var _widthUnavailable = 0
        private var _attachmentCreated = 0
        private var _attachmentPreserved = 0
        private var _attachmentRecycled = 0
        private var _incrementalUpdates = 0
        private var _fullInvalidations = 0
        private var _layoutSubviewsCalls = 0
        private var _tableFullLayoutPasses = 0

        func snapshot(isEnabled: Bool) -> RenderPipelineStats {
            guard isEnabled else { return .zero }
            return RenderPipelineStats(
                markdownAssignments: _markdownAssignments,
                streamingSchedules: _streamingSchedules,
                throttledExecutes: _throttledExecutes,
                renderCalls: _renderCalls,
                renderSkips: _renderSkips,
                widthUnavailable: _widthUnavailable,
                attachmentCreated: _attachmentCreated,
                attachmentPreserved: _attachmentPreserved,
                attachmentRecycled: _attachmentRecycled,
                incrementalUpdates: _incrementalUpdates,
                fullInvalidations: _fullInvalidations,
                layoutSubviewsCalls: _layoutSubviewsCalls,
                tableFullLayoutPasses: _tableFullLayoutPasses
            )
        }

        func reset() {
            _markdownAssignments = 0
            _streamingSchedules = 0
            _throttledExecutes = 0
            _renderCalls = 0
            _renderSkips = 0
            _widthUnavailable = 0
            _attachmentCreated = 0
            _attachmentPreserved = 0
            _attachmentRecycled = 0
            _incrementalUpdates = 0
            _fullInvalidations = 0
            _layoutSubviewsCalls = 0
            _tableFullLayoutPasses = 0
        }

        func markMarkdownAssignment(isEnabled: Bool) {
            guard isEnabled else { return }
            _markdownAssignments &+= 1
        }

        func markStreamingSchedule(isEnabled: Bool) {
            guard isEnabled else { return }
            _streamingSchedules &+= 1
        }

        func markThrottledExecute(isEnabled: Bool) {
            guard isEnabled else { return }
            _throttledExecutes &+= 1
        }

        func markRenderCall(isEnabled: Bool) {
            guard isEnabled else { return }
            _renderCalls &+= 1
        }

        func markRenderSkip(isEnabled: Bool) {
            guard isEnabled else { return }
            _renderSkips &+= 1
        }

        func markWidthUnavailable(isEnabled: Bool) {
            guard isEnabled else { return }
            _widthUnavailable &+= 1
        }

        func markAttachmentStats(isEnabled: Bool, created: Int, preserved: Int, recycled: Int) {
            guard isEnabled else { return }
            _attachmentCreated &+= created
            _attachmentPreserved &+= preserved
            _attachmentRecycled &+= recycled
        }

        func markIncrementalUpdate(isEnabled: Bool) {
            guard isEnabled else { return }
            _incrementalUpdates &+= 1
        }

        func markFullInvalidation(isEnabled: Bool) {
            guard isEnabled else { return }
            _fullInvalidations &+= 1
        }

        func markLayoutSubviewsCall(isEnabled: Bool) {
            guard isEnabled else { return }
            _layoutSubviewsCalls &+= 1
        }

        func markTableLayoutPasses(isEnabled: Bool, count: Int) {
            guard isEnabled else { return }
            _tableFullLayoutPasses &+= count
        }
    }
    
    private static let renderSignposter = OSSignposter(
        subsystem: "com.stx.markdown", category: "Rendering"
    )
    
    public var theme: MarkdownTheme = .default {
        didSet {
            cacheManager.invalidateDocument()
            renderIfReady()
        }
    }
    
    public var imageHandler: MarkdownImageHandler = DefaultImageHandler() {
        didSet {
            cacheManager.invalidateDocument()
            renderIfReady()
        }
    }
    
    public var isStreaming: Bool {
        get { streamingManager.isEnabled }
        set {
            MarkdownLogger.info(.streaming, "streaming state changed -> \(newValue)")
            _attachmentPool.logStats(context: "streaming toggle")
            streamingManager.isEnabled = newValue
        }
    }
    
    public var throttleInterval: TimeInterval {
        get { streamingManager.throttleInterval }
        set { streamingManager.throttleInterval = newValue }
    }

    public var isRenderPipelineStatsEnabled: Bool = false
    
    public var markdown: String = "" {
        didSet {
            statsCollector.markMarkdownAssignment(isEnabled: isRenderPipelineStatsEnabled)
            if isStreaming {
                let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
                streamingManager.scheduleRender(content: markdown, width: width, inputVersion: cacheManager.inputVersion)
            } else {
                cacheManager.invalidateDocument()
                renderIfReady()
            }
        }
    }
    
    public var preferredMaxLayoutWidth: CGFloat = 0 {
        didSet {
            applyPreferredTextContainerWidth()

            if preferredMaxLayoutWidth != oldValue, !markdown.isEmpty {
                renderIfReady()
            }
        }
    }
    
    private let _attachmentPool = AttachmentPool()
    private let tableSizeCache = TableCellSizeCache()
    private let streamingManager = StreamingManager()
    private let cacheManager = RenderCacheManager()
    private let statsCollector = RenderPipelineStatsCollector()
    
    private var lastRenderWasStreaming: Bool = false
    private var lastRenderedResult: RenderedMarkdown?
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupStreamingManager()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupStreamingManager()
    }
    
    public convenience init(theme: MarkdownTheme = .default) {
        self.init(frame: .zero, textContainer: nil)
        self.theme = theme
    }
    
    private func setupStreamingManager() {
        streamingManager.onExecuteRender = { [weak self] in
            self?.executeThrottledRender()
        }
        streamingManager.shouldSkipRender = { [weak self] content, width, version in
            guard let self else { return false }
            return cacheManager.shouldSkipRender(markdown: content, width: width)
        }
    }
    
    open override var intrinsicContentSize: CGSize {
        let containerWidth = textContainer.size.width
        if let cached = cacheManager.validIntrinsicSize(for: containerWidth) {
            return cached
        }
        layoutManager.ensureLayout(for: textContainer)
        let size = layoutManager.usedRect(for: textContainer).size
        let insets = textContainerInset
        let finalSize = CGSize(
            width: ceil(size.width + insets.left + insets.right),
            height: ceil(size.height + insets.top + insets.bottom + 1)
        )
        cacheManager.cacheRenderResult(
            markdown: markdown,
            width: preferredMaxLayoutWidth,
            attributedString: attributedText ?? NSAttributedString(),
            intrinsicSize: finalSize,
            containerWidth: containerWidth
        )
        return finalSize
    }
    
    private func renderIfReady() {
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        
        if width > 0 {
            render(with: width)
        } else {
            statsCollector.markWidthUnavailable(isEnabled: isRenderPipelineStatsEnabled)
            setNeedsLayout()
        }
    }
    
    open override func layoutSubviews() {
        statsCollector.markLayoutSubviewsCall(isEnabled: isRenderPipelineStatsEnabled)
        applyPreferredTextContainerWidth()

        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        
        if width > 0 && !markdown.isEmpty {
            let widthChanged = abs(width - cacheManager.lastRenderedWidth) > Self.widthEpsilon
            if widthChanged {
                render(with: width)
            }
        }

        applyPreferredTextContainerWidth()
        super.layoutSubviews()
        applyPreferredTextContainerWidth()
    }
    
    private func render(with width: CGFloat) {
        statsCollector.markRenderCall(isEnabled: isRenderPipelineStatsEnabled)
        
        if cacheManager.shouldSkipRender(markdown: markdown, width: width) {
            statsCollector.markRenderSkip(isEnabled: isRenderPipelineStatsEnabled)
            return
        }
        
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
            cacheManager.reset()
            invalidateIntrinsicContentSize()
            return
        }
        
        let codeBlockState: CodeBlockAnalyzer.CodeBlockState? = isStreaming ? CodeBlockAnalyzer.analyze(markdown) : nil
        
        let renderer = MarkdownRenderer(theme: theme, imageHandler: imageHandler, maxLayoutWidth: width, tableSizeCache: tableSizeCache)
        
        MarkdownTableView._computeLayoutCallCount = 0
        let parseSignpostState = Self.renderSignposter.beginInterval("Parse", id: Self.renderSignposter.makeSignpostID())
        let result: RenderedMarkdown
        if let document = cacheManager.document {
            result = renderer.render(document, attachmentPool: _attachmentPool, codeBlockState: codeBlockState, isStreaming: isStreaming)
        } else {
            let document = renderer.parse(markdown)
            cacheManager.cacheDocument(document)
            result = renderer.render(document, attachmentPool: _attachmentPool, codeBlockState: codeBlockState, isStreaming: isStreaming)
        }
        
        Self.renderSignposter.endInterval("Parse", parseSignpostState)
        let tablePassesDuringParse = MarkdownTableView._computeLayoutCallCount
        
        let reconcileSignpostState = Self.renderSignposter.beginInterval("Reconcile", id: Self.renderSignposter.makeSignpostID())
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
        var recycledCount = 0
        for entries in oldByKey.values {
            for entry in entries {
                let isTrailing = recycleToStreamingPool && entry.position == maxOldPos
                _attachmentPool.recycle(entry.info.view, anyKey: entry.info.contentKey, isStreaming: isTrailing)
                recycledCount += 1
            }
        }
        Self.renderSignposter.endInterval("Reconcile", reconcileSignpostState)
        let preservedCount = preservedOldViewIDs.count
        statsCollector.markAttachmentStats(
            isEnabled: isRenderPipelineStatsEnabled,
            created: result.attachments.count - preservedCount,
            preserved: preservedCount,
            recycled: recycledCount
        )
        statsCollector.markTableLayoutPasses(isEnabled: isRenderPipelineStatsEnabled, count: tablePassesDuringParse)
        
        let textStorageSignpostState = Self.renderSignposter.beginInterval("TextStorage", id: Self.renderSignposter.makeSignpostID())
        let (didIncrementalUpdate, changeStart) = updateTextStorage(result: result)
        Self.renderSignposter.endInterval("TextStorage", textStorageSignpostState)
        
        let layoutSignpostState = Self.renderSignposter.beginInterval("Layout", id: Self.renderSignposter.makeSignpostID())
        
        if let changeStart = changeStart {
            statsCollector.markIncrementalUpdate(isEnabled: isRenderPipelineStatsEnabled)
            let changedRange = NSRange(location: changeStart, length: textStorage.length - changeStart)
            layoutManager.invalidateLayout(forCharacterRange: changedRange, actualCharacterRange: nil)
        } else {
            statsCollector.markFullInvalidation(isEnabled: isRenderPipelineStatsEnabled)
            layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
        }
        layoutManager.ensureLayout(for: textContainer)
        markAttachmentLayoutEnsured(forWidth: width)
        
        attachmentViews = finalAttachments
        if let changeStart = changeStart {
            setNeedsAttachmentLayout(fromCharacterIndex: changeStart)
            markAttachmentLayoutEnsured(forWidth: width)
        }
        lastRenderedResult = RenderedMarkdown(attributedString: result.attributedString, attachments: finalAttachments)
        _attachmentPool.logStats(context: "after render")
        
        let maxPoolRetention = max(finalAttachments.count * 2, 10)
        _attachmentPool.trimToSize(maxPoolRetention)
        Self.renderSignposter.endInterval("Layout", layoutSignpostState)
        
        let usedSize = layoutManager.usedRect(for: textContainer).size
        let insets = textContainerInset
        let newHeight = ceil(usedSize.height + insets.top + insets.bottom + 1)
        let newWidth = ceil(usedSize.width + insets.left + insets.right)
        let newICS = CGSize(width: newWidth, height: newHeight)
        
        let previousHeight = cacheManager.intrinsicSize?.height ?? -1
        cacheManager.cacheRenderResult(
            markdown: markdown,
            width: width,
            attributedString: result.attributedString,
            intrinsicSize: newICS,
            containerWidth: textContainer.size.width
        )
        
        if isStreaming {
            if abs(newHeight - previousHeight) > 0.5 {
                invalidateIntrinsicContentSize()
            }
        } else {
            invalidateIntrinsicContentSize()
        }
        
        MarkdownLogger.debug(.view, "render completed, attachments=\(result.attachments.count)")
    }

    private func updateTextStorage(result: RenderedMarkdown) -> (didIncremental: Bool, changeStart: Int?) {
        var incrementalChangeStart: Int?
        
        if let previous = cacheManager.lastRenderedString {
            let newString = result.attributedString
            let commonPrefix = findCommonPrefixLength(previous, newString)
            let oldLen = previous.length
            let newLen = newString.length
            
            if commonPrefix == oldLen && commonPrefix == newLen {
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
        
        cacheManager.lastRenderedString = result.attributedString
        return (incrementalChangeStart != nil, incrementalChangeStart)
    }

    private func executeThrottledRender() {
        statsCollector.markThrottledExecute(isEnabled: isRenderPipelineStatsEnabled)
        
        cacheManager.invalidateDocument()
        let width = preferredMaxLayoutWidth > 0 ? preferredMaxLayoutWidth : bounds.width
        if width > 0 {
            render(with: width)
            setNeedsLayout()
        } else {
            statsCollector.markWidthUnavailable(isEnabled: isRenderPipelineStatsEnabled)
            setNeedsLayout()
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
    
    public override func cleanUp() {
        super.cleanUp()
        markdown = ""
        cacheManager.reset()
        streamingManager.reset()
        
        lastRenderWasStreaming = false
        
        tableSizeCache.clearAll()
        _attachmentPool.trimToSize(0)
    }
}

extension MarkdownView {
    public static var logLevel: MarkdownLogLevel {
        get { MarkdownLogger.level }
        set { MarkdownLogger.level = newValue }
    }
}
