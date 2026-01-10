import UIKit

// MARK: - Quote View
public class QuoteView: UIView {
    private let textView = MarkdownTextView()
    private let border = UIView()
    private let padding: CGFloat
    private let borderWidth: CGFloat
    
    public init(attributedText: NSAttributedString, attachments: [Int: UIView], theme: MarkdownTheme) {
        self.padding = theme.quote.padding
        self.borderWidth = theme.quote.borderWidth
        super.init(frame: .zero)
        setupUI(theme: theme)
        configure(attributedText: attributedText, attachments: attachments)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    // Constraint to force specific width during layout calculation
    private var widthConstraint: NSLayoutConstraint?

    public var preferredMaxLayoutWidth: CGFloat? {
        didSet {
            if let width = preferredMaxLayoutWidth {
                let totalSidePadding = borderWidth + padding + 8
                let innerWidth = width - totalSidePadding
                
                if widthConstraint == nil {
                    widthConstraint = textView.widthAnchor.constraint(equalToConstant: innerWidth)
                    widthConstraint?.isActive = true
                } else {
                    widthConstraint?.constant = innerWidth
                }
            } else {
                widthConstraint?.isActive = false
                widthConstraint = nil
            }
        }
    }

    private func setupUI(theme: MarkdownTheme) {
        backgroundColor = theme.quote.backgroundColor
        layer.cornerRadius = 4
        clipsToBounds = true 
        
        // Border
        border.backgroundColor = theme.quote.borderColor
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)
        
        // TextView - uses MarkdownTextView for attachment layout
        textView.backgroundColor = .clear
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(textView)
        
        NSLayoutConstraint.activate([
            // Border: Left side, full height, fixed width
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.topAnchor.constraint(equalTo: topAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.widthAnchor.constraint(equalToConstant: borderWidth),
            
            // TextView: Right of border
            textView.leadingAnchor.constraint(equalTo: border.trailingAnchor, constant: padding),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    private func configure(attributedText: NSAttributedString, attachments: [Int: UIView]) {
        textView.attributedText = attributedText
        textView.attachmentViews = attachments
    }
}
