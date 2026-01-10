import UIKit

class ChatBubbleCell: UITableViewCell {
    
    private let bubbleView = UIView()
    private let markdownView = MarkdownView()
    
    private var currentMarkdown: String?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let availableWidth = contentView.bounds.width - 32 - 24
        if availableWidth > 0 && markdownView.preferredMaxLayoutWidth != availableWidth {
            markdownView.preferredMaxLayoutWidth = availableWidth
            // 如果宽度变化且有内容，需要触发重新布局
            if currentMarkdown != nil {
                invalidateIntrinsicContentSize()
            }
        }
    }
    
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
        
        // MarkdownView (UITextView subclass)
        markdownView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.addSubview(markdownView)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            markdownView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            markdownView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -12),
            markdownView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            markdownView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)
        ])
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        currentMarkdown = nil
        markdownView.cleanUp()
    }
    
    func configure(with markdown: String) {
        currentMarkdown = markdown
        
        // 如果此时已有正确的宽度，直接设置
        let availableWidth = contentView.bounds.width - 32 - 24
        if availableWidth > 0 {
            markdownView.preferredMaxLayoutWidth = availableWidth
        }

        markdownView.markdown = markdown
    }
}
