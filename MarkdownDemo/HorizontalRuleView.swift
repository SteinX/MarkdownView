import UIKit

// MARK: - Horizontal Rule View
public class HorizontalRuleView: UIView {
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
}
