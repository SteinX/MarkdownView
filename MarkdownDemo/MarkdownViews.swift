import UIKit

// MARK: - Code Block View
class CodeBlockView: UIView {
    private let headerView = UIView()
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
        
        // Header
        headerView.backgroundColor = theme.codeHeaderColor
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        label.text = code
        label.font = theme.codeFont
        label.textColor = theme.codeTextColor
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .systemGray
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(headerView)
        headerView.addSubview(copyButton)
        addSubview(label)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 38),
            
            copyButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            copyButton.widthAnchor.constraint(equalToConstant: 30),
            copyButton.heightAnchor.constraint(equalToConstant: 30),
            
            label.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 12),
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

// MARK: - Table View

// MARK: - Table View

class MarkdownTableCell: UICollectionViewCell {
    let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        
        contentView.layer.borderWidth = 0.5
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(attributedText: NSAttributedString, theme: MarkdownTheme, isHeader: Bool) {
        label.attributedText = attributedText
        contentView.backgroundColor = isHeader ? theme.tableHeaderColor : .clear
        contentView.layer.borderColor = theme.tableBorderColor.cgColor
    }
}

class MarkdownTableView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private let headers: [NSAttributedString]
    private let rows: [[NSAttributedString]]
    private let theme: MarkdownTheme
    
    private var scrollView: UIScrollView!
    private var collectionView: UICollectionView!
    
    // Layout Data
    private var columnWidths: [CGFloat] = []
    private var rowHeights: [CGFloat] = []
    private var tableContentSize: CGSize = .zero
    
    init(headers: [NSAttributedString], rows: [[NSAttributedString]], theme: MarkdownTheme) {
        self.headers = headers
        self.rows = rows
        self.theme = theme
        super.init(frame: .zero)
        calculateLayoutData()
        setupUI()
    }
    
    override var intrinsicContentSize: CGSize {
        return tableContentSize
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func calculateLayoutData() {
        let (width, height, widths, heights) = MarkdownTableView.calculateLayout(headers: headers, rows: rows, theme: theme)
        self.tableContentSize = CGSize(width: width, height: height)
        self.columnWidths = widths
        self.rowHeights = heights
    }
    
    private func setupUI() {
        // 1. ScrollView for Horizontal Scrolling
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.bounces = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)
        
        // 2. CollectionView with FlowLayout
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        // No fixed itemSize here, sizeForItemAt delegate handles it
        layout.scrollDirection = .vertical
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MarkdownTableCell.self, forCellWithReuseIdentifier: "Cell")
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isScrollEnabled = false // Inner content doesn't scroll itself
        
        scrollView.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            // ScrollView fills the container view
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            // CollectionView pinned to ScrollView content guide
            collectionView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            
            // Critical constraints: Force CollectionView to match content size
            collectionView.widthAnchor.constraint(equalToConstant: tableContentSize.width),
            collectionView.heightAnchor.constraint(equalToConstant: tableContentSize.height),
            
             // Ensure ScrollView content height matches table height
             scrollView.contentLayoutGuide.heightAnchor.constraint(equalToConstant: tableContentSize.height)
        ])
        
        // Border
        layer.borderWidth = 1
        layer.borderColor = theme.tableBorderColor.cgColor
        layer.cornerRadius = 4
        clipsToBounds = true
    }
    
    // MARK: - DataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return rows.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return headers.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! MarkdownTableCell
        
        let isHeader = indexPath.section == 0
        let attributedText: NSAttributedString
        
        if isHeader {
            attributedText = headers[indexPath.item]
        } else {
            let rowData = rows[indexPath.section - 1]
            attributedText = indexPath.item < rowData.count ? rowData[indexPath.item] : NSAttributedString(string: "")
        }
        
        cell.configure(attributedText: attributedText, theme: theme, isHeader: isHeader)
        return cell
    }
    
    // MARK: - FlowLayout Delegate
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = columnWidths[indexPath.item]
        let height = rowHeights[indexPath.section]
        return CGSize(width: width, height: height)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
    
    // MARK: - Layout Calculation (Static & Internal)
    
    static func computedSize(headers: [NSAttributedString], rows: [[NSAttributedString]], theme: MarkdownTheme, maxWidth: CGFloat) -> CGSize {
        let (totalWidth, totalHeight, _, _) = calculateLayout(headers: headers, rows: rows, theme: theme)
        // Return size clamped to maxWidth for the View frame, but retain full height
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }
    
    private static func calculateLayout(headers: [NSAttributedString], rows: [[NSAttributedString]], theme: MarkdownTheme) -> (CGFloat, CGFloat, [CGFloat], [CGFloat]) {
        let padding: CGFloat = 16
        var colWidths = Array(repeating: CGFloat(0), count: headers.count)
        
        let allRows = [headers] + rows
        
        // 1. Widths
        for (rowIndex, _) in allRows.enumerated() {
             let row = allRows[rowIndex]
            
            for (colIndex, val) in row.enumerated() {
                if colIndex < colWidths.count {
                    let width = val.boundingRect(
                        with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 1000),
                        options: .usesLineFragmentOrigin,
                        context: nil
                    ).width + padding + 1
                    colWidths[colIndex] = max(colWidths[colIndex], width)
                }
            }
        }
        
        // 2. Heights
        var rowHeights: [CGFloat] = []
        for (rowIndex, _) in allRows.enumerated() {
             let row = allRows[rowIndex]
             var maxHeight: CGFloat = 40
            
            for (colIndex, val) in row.enumerated() {
                if colIndex < colWidths.count {
                    let width = colWidths[colIndex]
                    let textWidth = width - padding
                    let height = val.boundingRect(
                        with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: .usesLineFragmentOrigin,
                        context: nil
                    ).height + padding
                    maxHeight = max(maxHeight, height)
                }
            }
            rowHeights.append(maxHeight)
        }
        
        let totalWidth = colWidths.reduce(0, +)
        let totalHeight = rowHeights.reduce(0, +)
        
        return (totalWidth, totalHeight, colWidths, rowHeights)
    }
}
