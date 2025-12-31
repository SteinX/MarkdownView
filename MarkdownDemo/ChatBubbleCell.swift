import UIKit
import Markdown

class ChatBubbleCell: UITableViewCell {
    
    private let bubbleView = UIView()
    private let markdownTextView = AttachmentTextView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        // Bubble Background
        bubbleView.backgroundColor = .systemBackground
        bubbleView.layer.cornerRadius = 12
        bubbleView.layer.borderWidth = 1
        bubbleView.layer.borderColor = UIColor.systemGray5.cgColor
        bubbleView.clipsToBounds = false
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(bubbleView)
        
        // TextView Configuration
        markdownTextView.isEditable = false
        markdownTextView.isSelectable = true
        markdownTextView.isScrollEnabled = false
        markdownTextView.backgroundColor = .clear
        markdownTextView.textContainerInset = .zero
        markdownTextView.textContainer.lineFragmentPadding = 0
        markdownTextView.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.addSubview(markdownTextView)

        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            markdownTextView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            markdownTextView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            markdownTextView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            markdownTextView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        markdownTextView.cleanUp()
        markdownTextView.attributedText = nil
    }
    
    func configure(with markdown: String) {
        let document = Document(parsing: markdown)
        
        // Calculate max width (Screen width - margins)
        let screenWidth: CGFloat
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            screenWidth = windowScene.screen.bounds.width
        } else {
            screenWidth = UIScreen.main.bounds.width
        }

        // margins: Cell(32) + Bubble(24) + Safety(8) -> Reduce risk of overflow due to rounding
        let maxWidth = screenWidth - 32 - 24 - 8
        
        var parser = MyMarkdownParser(theme: .default, maxLayoutWidth: maxWidth)
        let item = parser.parse(document)
        
        markdownTextView.attributedText = item.attributedString
        markdownTextView.attachmentViews = item.attachments
    }
}
