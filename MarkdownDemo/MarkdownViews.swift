import UIKit

// MARK: - Code Block View
class CodeBlockView: UIView {
    private let label = UILabel()
    private let copyButton = UIButton(type: .system)
    private let code: String
    
    init(code: String, theme: MarkdownTheme) {
        self.code = code
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = theme.codeBackgroundColor
        layer.cornerRadius = 6
        clipsToBounds = true
        
        label.text = code
        label.font = theme.codeFont
        label.textColor = theme.codeTextColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .systemGray
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(label)
        addSubview(copyButton)
        
        NSLayoutConstraint.activate([
            copyButton.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            copyButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            copyButton.widthAnchor.constraint(equalToConstant: 30),
            copyButton.heightAnchor.constraint(equalToConstant: 30),
            
            label.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    @objc private func copyCode() {
        UIPasteboard.general.string = code
        // Feedback animation could be added here
    }
}

// MARK: - Quote View
class QuoteView: UIView {
    init(text: NSAttributedString, theme: MarkdownTheme) {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = theme.quoteBackgroundColor
        layer.cornerRadius = 4
        
        let border = UIView()
        border.backgroundColor = theme.quoteBorderColor
        border.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.attributedText = text
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(border)
        addSubview(label)
        
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.topAnchor.constraint(equalTo: topAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.widthAnchor.constraint(equalToConstant: 4),
            
            label.leadingAnchor.constraint(equalTo: border.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Table View
class MarkdownTableCell: UICollectionViewCell {
    let label = UILabel()
    override init(frame: CGRect) {
        super.init(frame: frame)
        label.numberOfLines = 0
        label.textAlignment = .left
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor.separator.cgColor
    }
    required init?(coder: NSCoder) { fatalError() }
}

class MarkdownTableView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private var collectionView: UICollectionView!
    private let headers: [String]
    private let rows: [[String]]
    private let columnWidths: [CGFloat]
    private let rowHeights: [CGFloat]
    private let theme: MarkdownTheme
    
    // ScrollView container for horizontal scrolling
    private let scrollView = UIScrollView()
    
    init(headers: [String], rows: [[String]], columnWidths: [CGFloat], rowHeights: [CGFloat], totalSize: CGSize, theme: MarkdownTheme) {
        self.headers = headers
        self.rows = rows
        self.columnWidths = columnWidths
        self.rowHeights = rowHeights
        self.theme = theme
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false
        
        // 1. Configure ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)
        
        // 2. Configure CollectionView
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MarkdownTableCell.self, forCellWithReuseIdentifier: "Cell")
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false // Internal scrolling disabled, handled by parent ScrollView
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        scrollView.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            collectionView.widthAnchor.constraint(equalToConstant: totalSize.width),
            collectionView.heightAnchor.constraint(equalToConstant: totalSize.height)
        ])

        collectionView.reloadData()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return rows.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return columnWidths.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! MarkdownTableCell
        
        let text: String
        if indexPath.section == 0 {
            text = headers.indices.contains(indexPath.item) ? headers[indexPath.item] : ""
            cell.contentView.backgroundColor = theme.tableHeaderColor
            cell.label.font = theme.boldFont
        } else {
            let row = rows[indexPath.section - 1]
            text = row.indices.contains(indexPath.item) ? row[indexPath.item] : ""
            cell.contentView.backgroundColor = .clear
            cell.label.font = theme.baseFont
        }
        cell.label.text = text
        cell.label.textColor = theme.textColor
        cell.layer.borderColor = theme.tableBorderColor.cgColor
        cell.layer.borderWidth = 0.5
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = columnWidths[indexPath.item]
        let height = indexPath.section == 0 ? rowHeights[0] : rowHeights[indexPath.section]
        return CGSize(width: width, height: height)
    }
}
