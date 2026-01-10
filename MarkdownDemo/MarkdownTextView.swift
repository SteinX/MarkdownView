import UIKit

/// A UITextView subclass that handles positioning of custom attachment views.
/// Used by MarkdownView, QuoteView, and MarkdownTableView for consistent attachment layout.
open class MarkdownTextView: UITextView {
    
    public var attachmentViews: [Int: UIView] = [:] {
        didSet {
            // Remove old views
            oldValue.values.forEach { $0.removeFromSuperview() }
            // Add new views at bottom of z-order so selection stays on top
            attachmentViews.values.forEach { view in
                insertSubview(view, at: 0)
            }
        }
    }
    
    public override init(frame: CGRect, textContainer: NSTextContainer?) {
        // Force TextKit 1 to avoid "switching to compatibility mode" warnings
        var container = textContainer
        // Keep a strong reference to the storage during initialization to prevent deallocation
        // before super.init completes, which would break the LayoutManager -> Container link.
        var strongTextStorage: NSTextStorage?
        
        if container == nil {
            let layoutManager = NSLayoutManager()
            let textStorage = NSTextStorage()
            textStorage.addLayoutManager(layoutManager)
            let newContainer = NSTextContainer(size: frame.size)
            newContainer.widthTracksTextView = true
            layoutManager.addTextContainer(newContainer)
            container = newContainer
            strongTextStorage = textStorage
        }
        
        super.init(frame: frame, textContainer: container)
        
        // Ensure storage stays alive until ownership is transferred
        _ = strongTextStorage
        
        setup()
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        isEditable = false
        isSelectable = true
        isScrollEnabled = false
        tintColor = .systemBlue
        backgroundColor = .clear
        clipsToBounds = false
        textContainerInset = .zero
        textContainer.lineFragmentPadding = 0
        layoutManager.allowsNonContiguousLayout = false
    }
    
    // MARK: - Touch Handling
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Check attachment views first since they are inserted at 0 (behind text container)
        // We want them to receive touches if they are interactive (like MarkdownTableView)
        for view in attachmentViews.values {
            // Convert point to view's local coordinate system
            let localPoint = view.convert(point, from: self)
            if view.point(inside: localPoint, with: event) {
                // If the view (or its subviews) accepts the touch, return it
                if let hitResult = view.hitTest(localPoint, with: event) {
                    return hitResult
                }
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    open override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure layout is complete
        layoutManager.ensureLayout(for: textContainer)
        
        for (charIndex, view) in attachmentViews {
            guard charIndex < (attributedText?.length ?? 0) else { continue }
            
            // Find Glyph Index for Character
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
            
            // Calculate Frame
            var rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)

            // Some attachment glyphs can report a zero rect; fall back to attachment bounds.
            if rect.size == .zero {
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                let attachmentSize = (attributedText?.attribute(.attachment, at: charIndex, effectiveRange: nil) as? NSTextAttachment)?.bounds.size ?? .zero
                rect = CGRect(origin: glyphLocation, size: attachmentSize)
            }
            
            // Convert Coordinates
            let finalRect = rect.offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
            
            // Update View Frame
            if view.frame != finalRect {
                view.frame = finalRect
                view.setNeedsLayout()
                view.layoutIfNeeded()
            }
        }
    }
    
    /// Cleanup method for Cell reuse
    public func cleanUp() {
        attachmentViews.values.forEach { $0.removeFromSuperview() }
        attachmentViews.removeAll()
        attributedText = nil
    }
}
