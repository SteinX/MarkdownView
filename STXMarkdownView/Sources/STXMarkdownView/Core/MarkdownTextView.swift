import UIKit

/// A UITextView subclass that handles positioning of custom attachment views.
/// Used by MarkdownView, QuoteView, and MarkdownTableView for consistent attachment layout.
open class MarkdownTextView: UITextView {
    
    // MARK: - Attachment Layout Tracking
    
    /// When false, layoutSubviews skips the expensive attachment positioning loop.
    /// Set to true when attachmentViews changes, textStorage is edited, or bounds width changes.
    private var needsAttachmentLayout: Bool = true
    private var lastAttachmentLayoutWidth: CGFloat = -1
    
    public var attachmentViews: [Int: AttachmentInfo] = [:] {
        didSet {
            needsAttachmentLayout = true
            let oldViewIDs = Set(oldValue.values.map { ObjectIdentifier($0.view) })
            let newViewIDs = Set(attachmentViews.values.map { ObjectIdentifier($0.view) })
            for info in oldValue.values where !newViewIDs.contains(ObjectIdentifier(info.view)) {
                info.view.removeFromSuperview()
            }
            for info in attachmentViews.values where !oldViewIDs.contains(ObjectIdentifier(info.view)) {
                insertSubview(info.view, at: 0)
            }
            setNeedsLayout()
        }
    }
    
    /// Marks attachment positions as needing recalculation.
    /// Called by subclasses when textStorage content changes without attachmentViews being reassigned.
    func setNeedsAttachmentLayout() {
        needsAttachmentLayout = true
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
        for info in attachmentViews.values {
            let view = info.view
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
        restoreTextContainerConfiguration()
        
        let currentWidth = bounds.width
        let widthChanged = abs(currentWidth - lastAttachmentLayoutWidth) > CGFloat.ulpOfOne
        
        guard needsAttachmentLayout || widthChanged else { return }
        
        layoutManager.ensureLayout(for: textContainer)
        
        let attachmentCount = attachmentViews.count
        if attachmentCount > 0 {
            MarkdownLogger.verbose(.layout, "layoutSubviews positioning \(attachmentCount) attachments")
        }
        
        for (charIndex, info) in attachmentViews {
            let view = info.view
            guard charIndex < (attributedText?.length ?? 0) else { continue }
            
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
            
            var rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)

            if rect.size == .zero {
                let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                let attachmentSize = (attributedText?.attribute(.attachment, at: charIndex, effectiveRange: nil) as? NSTextAttachment)?.bounds.size ?? .zero
                let origin = CGPoint(x: lineFragmentRect.origin.x + glyphLocation.x, y: lineFragmentRect.origin.y)
                rect = CGRect(origin: origin, size: attachmentSize)
            }
            
            let finalRect = rect.offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
            
            if view.frame != finalRect {
                view.frame = finalRect
                view.setNeedsLayout()
            }
        }
        
        needsAttachmentLayout = false
        lastAttachmentLayoutWidth = currentWidth
    }
    
    open func restoreTextContainerConfiguration() { }

    /// Cleanup method for Cell reuse
    public func cleanUp() {
        attachmentViews.values.forEach { $0.view.removeFromSuperview() }
        attachmentViews.removeAll()
        attributedText = nil
        lastAttachmentLayoutWidth = -1
    }

}
