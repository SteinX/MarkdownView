import UIKit

// MARK: - Table View

public class MarkdownTableCell: UICollectionViewCell {
    let textView = MarkdownTextView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
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
    
    func configure(attributedText: NSAttributedString, attachments: [Int: AttachmentInfo], theme: MarkdownTheme, isHeader: Bool) {
        textView.attributedText = attributedText
        textView.attachmentViews = attachments
        
        contentView.backgroundColor = isHeader ? theme.tables.headerColor : .clear
        contentView.layer.borderColor = theme.tables.borderColor.cgColor
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        textView.cleanUp()
    }
}

public struct MarkdownTableContentKey: AttachmentContentKey {
    public let dataHash: Int
    public let width: CGFloat
    public let isInsideQuote: Bool

    public init(dataHash: Int, width: CGFloat, isInsideQuote: Bool) {
        self.dataHash = dataHash
        self.width = width
        self.isInsideQuote = isInsideQuote
    }
}

public struct MarkdownTableLayoutResult {
    public let contentSize: CGSize
    public let columnWidths: [CGFloat]
    public let rowHeights: [CGFloat]
}

public class MarkdownTableView: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, Reusable {
    // Data now includes Attachments
    private var headers: [(NSAttributedString, [Int: AttachmentInfo])]
    private var rows: [[(NSAttributedString, [Int: AttachmentInfo])]]
    private var theme: MarkdownTheme
    private var maxLayoutWidth: CGFloat
    private var sizeCache: TableCellSizeCache?
    
    private var scrollView: UIScrollView!
    private var collectionView: UICollectionView!
    private var collectionWidthConstraint: NSLayoutConstraint?
    private var collectionHeightConstraint: NSLayoutConstraint?
    private var scrollContentHeightConstraint: NSLayoutConstraint?
    
    // Layout Data
    private var columnWidths: [CGFloat] = []
    private var rowHeights: [CGFloat] = []
    private var tableContentSize: CGSize = .zero
    
    public init(headers: [(NSAttributedString, [Int: AttachmentInfo])], rows: [[(NSAttributedString, [Int: AttachmentInfo])]], theme: MarkdownTheme, maxLayoutWidth: CGFloat, precomputedLayout: MarkdownTableLayoutResult? = nil, sizeCache: TableCellSizeCache? = nil) {
        self.headers = headers
        self.rows = rows
        self.theme = theme
        self.maxLayoutWidth = maxLayoutWidth
        self.sizeCache = sizeCache
        super.init(frame: .zero)
        
        MarkdownLogger.debug(.table, "init cols=\(headers.count), rows=\(rows.count), maxWidth=\(Int(maxLayoutWidth))")

        if let precomputedLayout = precomputedLayout {
            applyLayout(precomputedLayout)
        } else {
            calculateLayoutData()
        }
        setupUI()
    }
    
    public override var intrinsicContentSize: CGSize {
        // Fix: Use maxLayoutWidth to allow internal scrolling logic to work
        return CGSize(width: min(tableContentSize.width, maxLayoutWidth), height: tableContentSize.height)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func calculateLayoutData() {
        let headerTexts = headers.map { $0.0 }
        let rowTexts = rows.map { row in row.map { $0.0 } }

        let result = MarkdownTableView.computeLayout(headers: headerTexts, rows: rowTexts, theme: theme, maxWidth: maxLayoutWidth, cache: sizeCache)
        applyLayout(result)
    }
    
    private func setupUI() {
        // 1. ScrollView for Horizontal Scrolling
        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.bounces = false
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delaysContentTouches = false
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
        collectionView.delaysContentTouches = false
        
        scrollView.addSubview(collectionView)
        
        let collectionWidth = collectionView.widthAnchor.constraint(equalToConstant: tableContentSize.width)
        let collectionHeight = collectionView.heightAnchor.constraint(equalToConstant: tableContentSize.height)
        let scrollHeight = scrollView.contentLayoutGuide.heightAnchor.constraint(equalToConstant: tableContentSize.height)
        collectionWidthConstraint = collectionWidth
        collectionHeightConstraint = collectionHeight
        scrollContentHeightConstraint = scrollHeight

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
            collectionWidth,
            collectionHeight,
            
             // Ensure ScrollView content height matches table height
             scrollHeight
        ])
        
        // Border
        layer.borderWidth = 1
        layer.borderColor = theme.tables.borderColor.cgColor
        layer.cornerRadius = 4
        clipsToBounds = true
    }

    public func update(headers: [(NSAttributedString, [Int: AttachmentInfo])], rows: [[(NSAttributedString, [Int: AttachmentInfo])]], theme: MarkdownTheme, maxLayoutWidth: CGFloat, precomputedLayout: MarkdownTableLayoutResult? = nil, sizeCache: TableCellSizeCache? = nil) {
        self.headers = headers
        self.rows = rows
        self.theme = theme
        self.maxLayoutWidth = maxLayoutWidth
        if let sizeCache = sizeCache {
            self.sizeCache = sizeCache
        }

        if let precomputedLayout = precomputedLayout {
            applyLayout(precomputedLayout)
        } else {
            calculateLayoutData()
        }

        collectionWidthConstraint?.constant = tableContentSize.width
        collectionHeightConstraint?.constant = tableContentSize.height
        scrollContentHeightConstraint?.constant = tableContentSize.height

        collectionView.reloadData()
        invalidateIntrinsicContentSize()
    }
    
    // MARK: - DataSource
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return rows.count + 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return headers.count
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! MarkdownTableCell
        
        let isHeader = indexPath.section == 0
        let cellData: (NSAttributedString, [Int: AttachmentInfo])
        
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
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = columnWidths[indexPath.item]
        let height = rowHeights[indexPath.section]
        return CGSize(width: width, height: height)
    }
    
    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
    }
    
    // MARK: - Layout Calculation (Static & Internal)
    
    public static func computeLayout(headers: [NSAttributedString], rows: [[NSAttributedString]], theme: MarkdownTheme, maxWidth: CGFloat, cache: TableCellSizeCache? = nil) -> MarkdownTableLayoutResult {
        let start = CFAbsoluteTimeGetCurrent()
        let result = MarkdownLogger.measure(.table, "calculateLayout") {
            calculateLayout(headers: headers, rows: rows, theme: theme, maxWidth: maxWidth, cache: cache)
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        if MarkdownLogger.level >= .debug {
            let rowCount = rows.count + 1
            let colCount = headers.count
            MarkdownLogger.debug(.table, "layout rows=\(rowCount) cols=\(colCount) maxWidth=\(Int(maxWidth)) time=\(String(format: "%.2f", elapsed))ms")
        }

        if elapsed >= 50 {
            let rowCount = rows.count + 1
            let colCount = headers.count
            MarkdownLogger.warning(.table, "layout spike rows=\(rowCount) cols=\(colCount) maxWidth=\(Int(maxWidth)) time=\(String(format: "%.2f", elapsed))ms")
        }

        if let cache = cache, MarkdownLogger.level >= .debug {
            let rowCount = rows.count + 1
            let colCount = headers.count
            cache.logStats(context: "layout rows=\(rowCount) cols=\(colCount)")
        }

        return result
    }
    
    private static func calculateLayout(headers: [NSAttributedString], rows: [[NSAttributedString]], theme: MarkdownTheme, maxWidth: CGFloat, cache: TableCellSizeCache?) -> MarkdownTableLayoutResult {
        let padding: CGFloat = 16
        let extraBuffer: CGFloat = 4
        // The minimum reasonable width for a column to prevent complete crushing
        let minColumnWidth: CGFloat = theme.tables.minColumnWidth
        
        let allRows = [headers] + rows
        let columnCount = headers.count
        
        // 1. Calculate Intrinsic Widths (Single Line Max)
        var intrinsicWidths = Array(repeating: CGFloat(0), count: columnCount)
        
        for (rowIndex, _) in allRows.enumerated() {
             let row = allRows[rowIndex]
            for (colIndex, val) in row.enumerated() {
                if colIndex < columnCount {
                    if let cachedWidth = cache?.intrinsicWidth(for: val) {
                        let width = cachedWidth + padding + extraBuffer
                        intrinsicWidths[colIndex] = max(intrinsicWidths[colIndex], width)
                    } else {
                        let rect = val.boundingRect(
                            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: 1000),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            context: nil
                        )
                        let measuredWidth = ceil(rect.width)
                        cache?.storeIntrinsic(text: val, width: measuredWidth, height: ceil(rect.height))
                        let width = measuredWidth + padding + extraBuffer
                        intrinsicWidths[colIndex] = max(intrinsicWidths[colIndex], width)
                    }
                }
            }
        }
        
        let totalIntrinsicWidth = intrinsicWidths.reduce(0, +)
        var finalColWidths = intrinsicWidths
        
        // 2. Resolve Final Widths with wrapping logic
        let hasEnoughSpace = totalIntrinsicWidth <= maxWidth
        let canCompressIdeally = maxWidth >= (CGFloat(columnCount) * minColumnWidth)
        
        // Respect Distribution Mode
        if theme.tables.columnDistribution == .scroll {
             finalColWidths = intrinsicWidths
        } else if !hasEnoughSpace && canCompressIdeally {
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
                    
                    if let cachedHeight = cache?.height(for: val, width: textWidth) {
                        let height = cachedHeight + padding
                        maxHeight = max(maxHeight, height)
                    } else {
                        let rect = val.boundingRect(
                            with: CGSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude),
                            options: [.usesLineFragmentOrigin, .usesFontLeading],
                            context: nil
                        )
                        let measuredHeight = ceil(rect.height)
                        cache?.storeHeight(text: val, width: textWidth, height: measuredHeight)
                        let height = measuredHeight + padding
                        maxHeight = max(maxHeight, height)
                    }
                }
            }
            rowHeights.append(maxHeight)
        }
        
        let totalWidth = finalColWidths.reduce(0, +)
        let totalHeight = rowHeights.reduce(0, +)

        let result = MarkdownTableLayoutResult(
            contentSize: CGSize(width: totalWidth, height: totalHeight),
            columnWidths: finalColWidths,
            rowHeights: rowHeights
        )

        return result
    }

    private func applyLayout(_ result: MarkdownTableLayoutResult) {
        self.tableContentSize = result.contentSize
        self.columnWidths = result.columnWidths
        self.rowHeights = result.rowHeights

        MarkdownLogger.verbose(.table, "layout: size=\(Int(result.contentSize.width))x\(Int(result.contentSize.height)), colWidths=\(result.columnWidths.map { Int($0) })")
    }
    
    // MARK: - Reuse Support
    
    /// Prepare view for reuse - recycle only (no update method)
    public func prepareForReuse() {
        // Collection view cells already handle their own cleanup via prepareForReuse
        collectionView?.reloadData()
    }
}
