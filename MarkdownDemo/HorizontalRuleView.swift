import UIKit

// MARK: - Horizontal Rule View
public class HorizontalRuleView: UIView, Reusable {
    public init(theme: MarkdownTheme, width: CGFloat) {
        super.init(frame: .zero)
        backgroundColor = theme.separatorColor
        translatesAutoresizingMaskIntoConstraints = false
        
        let height: CGFloat = 1
        let size = CGSize(width: width, height: height)
        // Force layout size
        self.frame = CGRect(origin: .zero, size: size)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    // MARK: - Reuse Support
    
    /// Update the view with new content
    public func update(theme: MarkdownTheme, width: CGFloat) {
        backgroundColor = theme.separatorColor
        let height: CGFloat = 1
        let size = CGSize(width: width, height: height)
        self.frame = CGRect(origin: .zero, size: size)
    }
    
    /// Prepare view for reuse
    public func prepareForReuse() {
        // Nothing to clean up for horizontal rule
    }
}

public struct HorizontalRuleContentKey: AttachmentContentKey {
    public let width: CGFloat
    public let isInsideQuote: Bool

    public init(width: CGFloat, isInsideQuote: Bool) {
        self.width = width
        self.isInsideQuote = isInsideQuote
    }
}
