import UIKit

// MARK: - Quote View
public class QuoteView: UIView, Reusable {
    private let textView = MarkdownTextView()
    private let border = UIView()
    private var padding: CGFloat
    private var borderWidth: CGFloat
    private var borderWidthConstraint: NSLayoutConstraint?
    private var textLeadingConstraint: NSLayoutConstraint?
    
    public init(attributedText: NSAttributedString, attachments: [Int: AttachmentInfo], theme: MarkdownTheme) {
        self.padding = theme.quote.padding
        self.borderWidth = theme.quote.borderWidth
        super.init(frame: .zero)
        
        MarkdownLogger.debug(.quote, "init textLength=\(attributedText.length), attachments=\(attachments.count)")
        
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
            applyPreferredWidth(preferredMaxLayoutWidth)
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
        
        if borderWidthConstraint == nil {
            borderWidthConstraint = border.widthAnchor.constraint(equalToConstant: borderWidth)
            borderWidthConstraint?.isActive = true
        }

        if textLeadingConstraint == nil {
            textLeadingConstraint = textView.leadingAnchor.constraint(equalTo: border.trailingAnchor, constant: padding)
            textLeadingConstraint?.isActive = true
        }

        NSLayoutConstraint.activate([
            // Border: Left side, full height, fixed width
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.topAnchor.constraint(equalTo: topAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            borderWidthConstraint!,
            
            // TextView: Right of border
            textLeadingConstraint!,
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    
    private func configure(attributedText: NSAttributedString, attachments: [Int: AttachmentInfo]) {
        textView.attributedText = attributedText
        textView.attachmentViews = attachments
    }

    public func update(attributedText: NSAttributedString, attachments: [Int: AttachmentInfo], theme: MarkdownTheme) {
        padding = theme.quote.padding
        borderWidth = theme.quote.borderWidth

        backgroundColor = theme.quote.backgroundColor
        border.backgroundColor = theme.quote.borderColor
        borderWidthConstraint?.constant = borderWidth
        textLeadingConstraint?.constant = padding

        applyPreferredWidth(preferredMaxLayoutWidth)
        configure(attributedText: attributedText, attachments: attachments)
    }

    private func applyPreferredWidth(_ width: CGFloat?) {
        if let width = width {
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

    
    // MARK: - Reuse Support
    
    /// Prepare view for reuse - recycle only (no update method)
    public func prepareForReuse() {
        textView.cleanUp()
        widthConstraint?.isActive = false
        widthConstraint = nil
    }
}

public struct QuoteContentKey: AttachmentContentKey {
    public let textHash: Int
    public let attachmentsHash: Int
    public let width: CGFloat
    public let isInsideQuote: Bool

    public init(textHash: Int, attachmentsHash: Int, width: CGFloat, isInsideQuote: Bool) {
        self.textHash = textHash
        self.attachmentsHash = attachmentsHash
        self.width = width
        self.isInsideQuote = isInsideQuote
    }
}
