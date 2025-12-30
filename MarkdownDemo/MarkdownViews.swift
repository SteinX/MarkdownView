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
    private let textView = AttachmentTextView()
    private let border = UIView()
    
    init(attributedText: NSAttributedString, attachments: [Int: UIView], theme: MarkdownTheme) {
        super.init(frame: .zero)
        setupUI(theme: theme)
        configure(attributedText: attributedText, attachments: attachments)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    // Constraint to force specific width during layout calculation
    private var widthConstraint: NSLayoutConstraint?

    var preferredMaxLayoutWidth: CGFloat? {
        didSet {
            if let width = preferredMaxLayoutWidth {
                // Calculate inner text view width: Total - (Border 4 + Left 12 + Right 8) = Total - 24
                let innerWidth = width - 24
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
        backgroundColor = theme.quoteBackgroundColor
        layer.cornerRadius = 4
        clipsToBounds = true 
        
        // Border
        border.backgroundColor = theme.quoteBorderColor
        border.translatesAutoresizingMaskIntoConstraints = false
        addSubview(border)
        
        // TextView
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        // Keep low compression resistance just in case
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(textView)
        
        NSLayoutConstraint.activate([
            // Border: Left side, full height, fixed width
            border.leadingAnchor.constraint(equalTo: leadingAnchor),
            border.topAnchor.constraint(equalTo: topAnchor),
            border.bottomAnchor.constraint(equalTo: bottomAnchor),
            border.widthAnchor.constraint(equalToConstant: 4),
            
            // TextView: Right of border
            textView.leadingAnchor.constraint(equalTo: border.trailingAnchor, constant: 12),
            // We keep the trailing constraint, but the explicit width constraint (if set) will dominate
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0)
        ])
    }
    
    private func configure(attributedText: NSAttributedString, attachments: [Int: UIView]) {
        textView.attributedText = attributedText
        textView.attachmentViews = attachments
    }
}

// MARK: - Table View

class MarkdownTableCell: UICollectionViewCell {
    let textView = AttachmentTextView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(textView)
        
        contentView.layer.borderWidth = 0.5
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            textView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            textView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(attributedText: NSAttributedString, attachments: [Int: UIView], theme: MarkdownTheme, isHeader: Bool) {
        textView.attributedText = attributedText
        textView.attachmentViews = attachments // AttachmentTextView logic handles this
        
        contentView.backgroundColor = isHeader ? theme.tableHeaderColor : .clear
        contentView.layer.borderColor = theme.tableBorderColor.cgColor
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        textView.cleanUp()
    }
}

class MarkdownTableView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    // Data now includes Attachments
    private let headers: [(NSAttributedString, [Int: UIView])]
    private let rows: [[(NSAttributedString, [Int: UIView])]]
    private let theme: MarkdownTheme
    private let maxLayoutWidth: CGFloat
    
    private var scrollView: UIScrollView!
    private var collectionView: UICollectionView!
    
    // Layout Data
    private var columnWidths: [CGFloat] = []
    private var rowHeights: [CGFloat] = []
    private var tableContentSize: CGSize = .zero
    
    init(headers: [(NSAttributedString, [Int: UIView])], rows: [[(NSAttributedString, [Int: UIView])]], theme: MarkdownTheme, maxLayoutWidth: CGFloat) {
        self.headers = headers
        self.rows = rows
        self.theme = theme
        self.maxLayoutWidth = maxLayoutWidth
        super.init(frame: .zero)
        calculateLayoutData()
        setupUI()
    }
    
    override var intrinsicContentSize: CGSize {
        return tableContentSize
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func calculateLayoutData() {
        let headerTexts = headers.map { $0.0 }
        let rowTexts = rows.map { row in row.map { $0.0 } }
        
        let (width, height, widths, heights) = MarkdownTableView.calculateLayout(headers: headerTexts, rows: rowTexts, theme: theme, maxWidth: maxLayoutWidth)
        self.tableContentSize = CGSize(width: width, height: height)
        self.columnWidths = widths
        self.rowHeights = heights
    }
    
    private func setupUI() {
        // 1. ScrollView for Horizontal Scrolling (Logic handles if it's actually needed)
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
        layout.scrollDirection = .vertical
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(MarkdownTableCell.self, forCellWithReuseIdentifier: "Cell")
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.isScrollEnabled = false
        
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
        let cellData: (NSAttributedString, [Int: UIView])
        
        if isHeader {
            cellData = headers[indexPath.item]
        } else {
            let rowData = rows[indexPath.section - 1]
            // Safe index check
            if indexPath.item < rowData.count {
                cellData = rowData[indexPath.item]
            } else {
                cellData = (NSAttributedString(string: ""), [:])
            }
        }
        
        cell.configure(attributedText: cellData.0, attachments: cellData.1, theme: theme, isHeader: isHeader)
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
        let (totalWidth, totalHeight, _, _) = calculateLayout(headers: headers, rows: rows, theme: theme, maxWidth: maxWidth)
        // Ensure the view frame doesn't exceed screen width, even if content scrolls internals
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }
    
    private static func calculateLayout(headers: [NSAttributedString], rows: [[NSAttributedString]], theme: MarkdownTheme, maxWidth: CGFloat) -> (CGFloat, CGFloat, [CGFloat], [CGFloat]) {
        let padding: CGFloat = 16
        let extraBuffer: CGFloat = 4
        // The minimum reasonable width for a column to prevent complete crushing
        let minColumnWidth: CGFloat = 60.0
        
        let allRows = [headers] + rows
        let columnCount = headers.count
        
        // 1. Calculate Intrinsic Widths (Single Line Max)
        var intrinsicWidths = Array(repeating: CGFloat(0), count: columnCount)
        
        for (rowIndex, _) in allRows.enumerated() {
             let row = allRows[rowIndex]
            for (colIndex, val) in row.enumerated() {
                if colIndex < columnCount {
                    let rect = val.boundingRect(
                        with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 1000),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    let width = ceil(rect.width) + padding + extraBuffer
                    intrinsicWidths[colIndex] = max(intrinsicWidths[colIndex], width)
                }
            }
        }
        
        let totalIntrinsicWidth = intrinsicWidths.reduce(0, +)
        var finalColWidths = intrinsicWidths
        
        // 2. Resolve Final Widths with wrapping logic
        let hasEnoughSpace = totalIntrinsicWidth <= maxWidth
        let canCompressIdeally = maxWidth >= (CGFloat(columnCount) * minColumnWidth)
        
        if !hasEnoughSpace && canCompressIdeally {
            // Smart Compression Strategy:
            // Identify "small" columns that fit comfortably within their share of space and freeze them.
            // Distribute remaining space to "large" columns.
            
            var resolvedWidths = Array(repeating: CGFloat(0), count: columnCount)
            var resolvedIndices = Set<Int>()
            var remainingWidth = maxWidth
            
            // Iteratively find columns that are smaller than the average available slot
            for _ in 0..<columnCount {
                let remainingCount = CGFloat(columnCount - resolvedIndices.count)
                if remainingCount == 0 { break }
                
                let averageAllocation = remainingWidth / remainingCount
                var progressMade = false
                
                for i in 0..<columnCount {
                    if !resolvedIndices.contains(i) {
                        if intrinsicWidths[i] <= averageAllocation {
                            // This column is small enough to keep its ideal size
                            resolvedWidths[i] = intrinsicWidths[i]
                            resolvedIndices.insert(i)
                            remainingWidth -= intrinsicWidths[i]
                            progressMade = true
                        }
                    }
                }
                
                if !progressMade {
                    // All remaining columns are larger than the average.
                    // Distribute remaining space equally (or proportionally) among them.
                    // Here we use equal distribution of the remainder as they are all "large"
                    let finalAllocation = floor(remainingWidth / remainingCount)
                    for i in 0..<columnCount {
                        if !resolvedIndices.contains(i) {
                            resolvedWidths[i] = max(minColumnWidth, finalAllocation)
                        }
                    }
                    break
                }
            }
            finalColWidths = resolvedWidths
        } else if !hasEnoughSpace && !canCompressIdeally {
            // Table has too many columns to fit on screen even at minimum widths.
            // Fallback: We MUST scroll horizontally.
            // Keep intrinsic widths so users can see full single-line content by scrolling.
            finalColWidths = intrinsicWidths
        }
        
        // 3. Calculate Heights (based on Final Widths)
        var rowHeights: [CGFloat] = []
        for (rowIndex, _) in allRows.enumerated() {
             let row = allRows[rowIndex]
             var maxHeight: CGFloat = 40
            
            for (colIndex, val) in row.enumerated() {
                if colIndex < columnCount {
                    let width = finalColWidths[colIndex]
                    let textWidth = max(1, width - padding) // Ensure > 0
                    
                    let rect = val.boundingRect(
                        with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                    let height = ceil(rect.height) + padding
                    maxHeight = max(maxHeight, height)
                }
            }
            rowHeights.append(maxHeight)
        }
        
        let totalWidth = finalColWidths.reduce(0, +)
        let totalHeight = rowHeights.reduce(0, +)
        
        return (totalWidth, totalHeight, finalColWidths, rowHeights)
    }
}

// MARK: - Horizontal Rule View
class HorizontalRuleView: UIView {
    init(theme: MarkdownTheme, width: CGFloat) {
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

// MARK: - Markdown Image View
class MarkdownImageView: UIView {
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let url: URL
    private let imageHandler: MarkdownImageHandler
    
    // For "grayed out" effect in quotes
    var isDimmed: Bool = false {
        didSet {
            updateDimmedState()
        }
    }
    
    init(url: URL, imageHandler: MarkdownImageHandler, theme: MarkdownTheme, isDimmed: Bool = false) {
        self.url = url
        self.imageHandler = imageHandler
        self.isDimmed = isDimmed
        super.init(frame: .zero)
        
        setupUI(theme: theme)
        loadImage()
        updateDimmedState()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI(theme: MarkdownTheme) {
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 4
        imageView.backgroundColor = theme.imageBackgroundColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Default placeholder
        imageView.image = theme.imageLoadingPlaceholder
        imageView.tintColor = .systemGray4
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(imageView)
        addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func updateDimmedState() {
        if isDimmed {
            imageView.alpha = 0.7
        } else {
            imageView.alpha = 1.0
        }
    }
    
    private func loadImage() {
        activityIndicator.startAnimating()
        imageHandler.loadImage(url: url, imageView: imageView) { [weak self] image in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            
            if let image = image {
                self.imageView.image = image
                self.imageView.contentMode = .scaleAspectFit
            }
        }
    }
}
