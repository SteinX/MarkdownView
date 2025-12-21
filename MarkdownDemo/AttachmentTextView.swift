import UIKit

class AttachmentTextView: UITextView {
    
    var attachmentViews: [Int: UIView] = [:] {
        didSet {
            // Remove old views
            oldValue.values.forEach { $0.removeFromSuperview() }
            // Add new views
            attachmentViews.values.forEach { addSubview($0) }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Ensure layout is complete
        layoutManager.ensureLayout(for: textContainer)
        
        for (charIndex, view) in attachmentViews {
            // Find Glyph Index for Character
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
            
            // Calculate Frame
            var rect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)

            // Some attachment glyphs can report a zero rect; fall back to attachment bounds.
            if rect.size == .zero {
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)
                let attachmentSize = (attributedText.attribute(.attachment, at: charIndex, effectiveRange: nil) as? NSTextAttachment)?.bounds.size ?? .zero
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

            // Keep overlay views above text rendering.
            bringSubviewToFront(view)
        }
    }
    
    // Cleanup method for Cell reuse
    func cleanUp() {
        attachmentViews.removeAll()
        subviews.forEach { view in
            if view is CodeBlockView || view is MarkdownTableView || view is QuoteView {
                view.removeFromSuperview()
            }
        }
    }
}
