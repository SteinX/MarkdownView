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
    
    public var markdown: String = "" {
        didSet {
            // Invalidate cache when content changes
            cachedDocument = nil
            renderIfReady()
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
        return CGSize(width: ceil(size.width + insets.left + insets.right), 
                      height: ceil(size.height + insets.top + insets.bottom + 1))
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
        
        // Set text container width for correct intrinsic size calculation
        textContainer.size.width = width
        
        // Clean up old attachments
        attachmentViews.values.forEach { $0.removeFromSuperview() }
        attachmentViews.removeAll()
        
        if markdown.isEmpty {
            attributedText = nil
            invalidateIntrinsicContentSize()
            return
        }
        
        let renderer = MarkdownRenderer(theme: theme, imageHandler: imageHandler, maxLayoutWidth: width)
        
        let result: RenderedMarkdown
        if let document = cachedDocument {
            // Reuse cached AST
            result = renderer.render(document)
        } else {
            // Parse and cache
            let document = renderer.parse(markdown)
            cachedDocument = document
            result = renderer.render(document)
        }
        
        attributedText = result.attributedString
        
        // Force TextKit to invalidate and recalculate layout immediately
        // This is crucial after cell reuse to avoid stale glyph positions
        layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: textStorage.length), actualCharacterRange: nil)
        layoutManager.ensureLayout(for: textContainer)
        
        attachmentViews = result.attachments
        
        // Force intrinsic size recalculation
        invalidateIntrinsicContentSize()
    }
    
    // MARK: - Cleanup
    
    /// Call this before reusing the view (e.g., in prepareForReuse)
    public override func cleanUp() {
        super.cleanUp()
        markdown = ""
        cachedDocument = nil
        lastRenderedWidth = 0
    }
}
