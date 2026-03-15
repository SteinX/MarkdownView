import UIKit
import os

/// A UITextView subclass that handles positioning of custom attachment views.
/// Used by MarkdownView, QuoteView, and MarkdownTableView for consistent attachment layout.
open class MarkdownTextView: UITextView {
    private static let layoutSignposter = OSSignposter(subsystem: "com.stx.markdown", category: "Layout")
    
    private(set) var needsAttachmentLayout = false
    private var lastAttachmentLayoutWidth: CGFloat = -1
    private var lastEnsuredLayoutWidth: CGFloat = -1
    private var minAttachmentLayoutCharIndex: Int?
    
    public var attachmentViews: [Int: AttachmentInfo] = [:] {
        didSet {
            needsAttachmentLayout = true
            minAttachmentLayoutCharIndex = nil
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
        lastEnsuredLayoutWidth = -1
        minAttachmentLayoutCharIndex = nil
    }

    func setNeedsAttachmentLayout(fromCharacterIndex index: Int) {
        needsAttachmentLayout = true
        lastEnsuredLayoutWidth = -1
        let clamped = max(0, index)
        if let existing = minAttachmentLayoutCharIndex {
            minAttachmentLayoutCharIndex = min(existing, clamped)
        } else {
            minAttachmentLayoutCharIndex = clamped
        }
    }

    func markAttachmentLayoutEnsured(forWidth width: CGFloat) {
        lastEnsuredLayoutWidth = width
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
        
        guard needsAttachmentLayout || widthChanged else {
            return
        }

        let attachmentCount = attachmentViews.count
        guard attachmentCount > 0 else {
            needsAttachmentLayout = false
            minAttachmentLayoutCharIndex = nil
            lastAttachmentLayoutWidth = currentWidth
            return
        }
        
        let layoutAlreadyEnsured = abs(currentWidth - lastEnsuredLayoutWidth) <= CGFloat.ulpOfOne
        if !layoutAlreadyEnsured {
            layoutManager.ensureLayout(for: textContainer)
            lastEnsuredLayoutWidth = currentWidth
        }

        if attachmentCount > 0 {
            MarkdownLogger.verbose(.layout, "layoutSubviews positioning \(attachmentCount) attachments")
        }

        let minCharIndexToLayout = widthChanged ? nil : minAttachmentLayoutCharIndex
        if let minCharIndexToLayout {
            let hasAffectedAttachment = attachmentViews.keys.contains { $0 >= minCharIndexToLayout }
            if !hasAffectedAttachment {
                needsAttachmentLayout = false
                minAttachmentLayoutCharIndex = nil
                lastAttachmentLayoutWidth = currentWidth
                return
            }
        }

        let attachmentLayoutSignpostState = Self.layoutSignposter.beginInterval("AttachmentLayout", id: Self.layoutSignposter.makeSignpostID())
        for (charIndex, info) in attachmentViews {
            if let minCharIndexToLayout, charIndex < minCharIndexToLayout {
                continue
            }
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
                // O8: Skip setNeedsLayout for position-only moves. UIKit automatically
                // triggers layoutSubviews when bounds.size changes via frame assignment.
                // During streaming, existing attachments shift down (same size, new origin)
                // — forcing internal re-layout of tables/code blocks is unnecessary and
                // is the primary source of ~100ms P99 layout overhead.
                let sizeChanged = abs(view.bounds.width - finalRect.width) > 0.5
                    || abs(view.bounds.height - finalRect.height) > 0.5
                view.frame = finalRect
                if sizeChanged {
                    view.setNeedsLayout()
                }
            }
        }
        Self.layoutSignposter.endInterval("AttachmentLayout", attachmentLayoutSignpostState)
        
        needsAttachmentLayout = false
        minAttachmentLayoutCharIndex = nil
        lastAttachmentLayoutWidth = currentWidth
    }
    
    open func restoreTextContainerConfiguration() { }

    /// Cleanup method for Cell reuse
    public func cleanUp() {
        attachmentViews.values.forEach { $0.view.removeFromSuperview() }
        attachmentViews.removeAll()
        attributedText = nil
        lastAttachmentLayoutWidth = -1
        lastEnsuredLayoutWidth = -1
    }

}
