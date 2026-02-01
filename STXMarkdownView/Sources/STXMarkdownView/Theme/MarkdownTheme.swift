import UIKit

public struct MarkdownTheme {
    public let baseFont: UIFont
    public let colors: LayoutColors
    public let headings: HeadingTheme
    public let code: CodeBlockTheme
    public let quote: QuoteTheme
    public let lists: ListTheme
    public let tables: TableTheme
    public let images: ImageTheme
    public let paragraphSpacing: CGFloat
    public let linkColor: UIColor
    public let separatorColor: UIColor
    
    // MARK: - Sub-Themes
    
    public struct LayoutColors {
        public let text: UIColor
        public let secondaryText: UIColor
        public let background: UIColor
        
        public init(text: UIColor, secondaryText: UIColor = .secondaryLabel, background: UIColor = .systemBackground) {
            self.text = text
            self.secondaryText = secondaryText
            self.background = background
        }
        
        public func dimmed() -> LayoutColors {
            // slightly more transparent or lighter text
            return LayoutColors(
                text: text.withAlphaComponent(0.8),
                secondaryText: secondaryText.withAlphaComponent(0.8),
                background: background
            )
        }
    }
    
    public struct HeadingTheme {
        public let fonts: [UIFont]
        public let spacings: [CGFloat]
        
        public init(fonts: [UIFont], spacings: [CGFloat]) {
            self.fonts = fonts
            self.spacings = spacings
        }
    }
    
    public struct CodeBlockTheme {
        public let font: UIFont
        public let backgroundColor: UIColor
        public let textColor: UIColor
        public let headerColor: UIColor
        public let languageLabelFont: UIFont
        public let languageLabelColor: UIColor
        public let syntaxHighlightTheme: String // Using String for loose coupling, can be String Enum in config
        public let isScrollable: Bool
        
        public init(font: UIFont, backgroundColor: UIColor, textColor: UIColor, headerColor: UIColor, languageLabelFont: UIFont, languageLabelColor: UIColor, syntaxHighlightTheme: String, isScrollable: Bool) {
            self.font = font
            self.backgroundColor = backgroundColor
            self.textColor = textColor
            self.headerColor = headerColor
            self.languageLabelFont = languageLabelFont
            self.languageLabelColor = languageLabelColor
            self.syntaxHighlightTheme = syntaxHighlightTheme
            self.isScrollable = isScrollable
        }
        
        public func dimmed() -> CodeBlockTheme {
             return CodeBlockTheme(
                font: font,
                // Use a significantly more transparent background for visible "dimming"/blending
                backgroundColor: backgroundColor.withAlphaComponent(0.2), 
                textColor: textColor.withAlphaComponent(0.6),
                headerColor: headerColor.withAlphaComponent(0.8),
                languageLabelFont: languageLabelFont,
                languageLabelColor: languageLabelColor.withAlphaComponent(0.6),
                syntaxHighlightTheme: syntaxHighlightTheme,
                isScrollable: isScrollable
            )
        }
    }
    
    public struct QuoteTheme {
        public let textColor: UIColor
        public let backgroundColor: UIColor
        public let borderColor: UIColor
        public let borderWidth: CGFloat
        public let padding: CGFloat
        
        public init(textColor: UIColor, backgroundColor: UIColor, borderColor: UIColor, borderWidth: CGFloat = 4.0, padding: CGFloat = 12.0) {
            self.textColor = textColor
            self.backgroundColor = backgroundColor
            self.borderColor = borderColor
            self.borderWidth = borderWidth
            self.padding = padding
        }
    }
    
    public struct ListTheme {
        public let baseFont: UIFont
        public let spacing: CGFloat
        public let indentStep: CGFloat
        public let markerSpacing: CGFloat
        public let bulletMarkers: [String]
        public let checkboxCheckedImage: UIImage?
        public let checkboxUncheckedImage: UIImage?
        public let checkboxColor: UIColor
        
        public init(baseFont: UIFont, spacing: CGFloat, indentStep: CGFloat, markerSpacing: CGFloat, bulletMarkers: [String], checkboxCheckedImage: UIImage?, checkboxUncheckedImage: UIImage?, checkboxColor: UIColor) {
            self.baseFont = baseFont
            self.spacing = spacing
            self.indentStep = indentStep
            self.markerSpacing = markerSpacing
            self.bulletMarkers = bulletMarkers
            self.checkboxCheckedImage = checkboxCheckedImage
            self.checkboxUncheckedImage = checkboxUncheckedImage
            self.checkboxColor = checkboxColor
        }
        
        public func dimmed() -> ListTheme {
            return ListTheme(
                baseFont: baseFont,
                spacing: spacing,
                indentStep: indentStep,
                markerSpacing: markerSpacing,
                bulletMarkers: bulletMarkers,
                checkboxCheckedImage: checkboxCheckedImage,
                checkboxUncheckedImage: checkboxUncheckedImage,
                checkboxColor: checkboxColor.withAlphaComponent(0.7)
            )
        }
    }
    
    public struct TableTheme {
        public enum ColumnDistribution {
            /// Attempts to compress columns to fit within the available width.
            /// If they cannot be compressed enough to respect `minColumnWidth`,
            /// the table will scroll horizontally.
            case automatic
            
            /// Always allows the table to exceed the available width and scroll horizontally,
            /// preserving the intrinsic width of columns (or at least `minColumnWidth`).
            case scroll
        }
        
        public let borderColor: UIColor
        public let headerColor: UIColor
        public let minColumnWidth: CGFloat
        public let columnDistribution: ColumnDistribution
        
        public init(
            borderColor: UIColor,
            headerColor: UIColor,
            minColumnWidth: CGFloat = 60.0,
            columnDistribution: ColumnDistribution = .automatic
        ) {
            self.borderColor = borderColor
            self.headerColor = headerColor
            self.minColumnWidth = minColumnWidth
            self.columnDistribution = columnDistribution
        }
        
        public func dimmed() -> TableTheme {
            return TableTheme(
                borderColor: borderColor.withAlphaComponent(0.6),
                headerColor: headerColor.withAlphaComponent(0.6),
                minColumnWidth: minColumnWidth,
                columnDistribution: columnDistribution
            )
        }
    }
    
    public struct ImageTheme {
        public let loadingPlaceholder: UIImage?
        public let backgroundColor: UIColor
        public let inlineSize: CGFloat
        
        public init(loadingPlaceholder: UIImage?, backgroundColor: UIColor, inlineSize: CGFloat) {
            self.loadingPlaceholder = loadingPlaceholder
            self.backgroundColor = backgroundColor
            self.inlineSize = inlineSize
        }
        
        public func dimmed() -> ImageTheme {
            return ImageTheme(
                loadingPlaceholder: loadingPlaceholder,
                backgroundColor: backgroundColor.withAlphaComponent(0.6),
                inlineSize: inlineSize
            )
        }
    }
    
    // MARK: - Init
    
    public init(
        baseFont: UIFont,
        colors: LayoutColors,
        headings: HeadingTheme,
        code: CodeBlockTheme,
        quote: QuoteTheme,
        lists: ListTheme,
        tables: TableTheme,
        images: ImageTheme,
        paragraphSpacing: CGFloat = 12,
        linkColor: UIColor = .link,
        separatorColor: UIColor = .separator
    ) {
        self.baseFont = baseFont
        self.colors = colors
        self.headings = headings
        self.code = code
        self.quote = quote
        self.lists = lists
        self.tables = tables
        self.images = images
        self.paragraphSpacing = paragraphSpacing
        self.linkColor = linkColor
        self.separatorColor = separatorColor
    }
    
    // MARK: - Default Theme
    
    public static let `default`: MarkdownTheme = {
        let baseFont = UIFont.systemFont(ofSize: 15)
        
        let colors = LayoutColors(
            text: .label,
            secondaryText: .secondaryLabel,
            background: .systemBackground
        )
        
        let headings = HeadingTheme(
            fonts: [
                .boldSystemFont(ofSize: 24),
                .boldSystemFont(ofSize: 20),
                .boldSystemFont(ofSize: 18),
                .boldSystemFont(ofSize: 16),
                .systemFont(ofSize: 16, weight: .bold),
                .systemFont(ofSize: 14, weight: .bold)
            ],
            spacings: [16, 12, 10, 8, 8, 8]
        )
        
        let code = CodeBlockTheme(
            font: .monospacedSystemFont(ofSize: 13, weight: .regular),
            backgroundColor: .secondarySystemBackground,
            textColor: .label,
            headerColor: .systemGray5,
            languageLabelFont: .systemFont(ofSize: 12, weight: .medium),
            languageLabelColor: .secondaryLabel,
            syntaxHighlightTheme: "atom-one-dark",
            isScrollable: false
        )
        
        let quote = QuoteTheme(
            textColor: .secondaryLabel,
            backgroundColor: .systemGray6,
            borderColor: .systemGray4
        )
        
        let lists = ListTheme(
            baseFont: baseFont,
            spacing: 4,
            indentStep: 20,
            markerSpacing: 24,
            bulletMarkers: ["•", "◦", "■"],
            checkboxCheckedImage: UIImage(systemName: "checkmark.square"),
            checkboxUncheckedImage: UIImage(systemName: "square"),
            checkboxColor: .link
        )
        
        let tables = TableTheme(
            borderColor: .systemGray4,
            headerColor: .systemGray5,
            minColumnWidth: 60,
            columnDistribution: .automatic
        )
        
        let images = ImageTheme(
            loadingPlaceholder: UIImage(systemName: "photo"),
            backgroundColor: .clear,
            inlineSize: 20
        )
        
        return MarkdownTheme(
            baseFont: baseFont,
            colors: colors,
            headings: headings,
            code: code,
            quote: quote,
            lists: lists,
            tables: tables,
            images: images
        )
    }()
    
    // MARK: - Convenience for Dimmed/Quoted State
    
    public var quoted: MarkdownTheme {
        // Use the dimmed versions of the sub-themes
        // Override global text colors with quote specific ones (or combine)
        

        let newCode = code.dimmed()
        let newLists = lists.dimmed()
        let newTables = tables.dimmed()
        let newImages = images.dimmed()
        
        // We might want to force specific text colors for the "main" quote text
        // But for nested structures, dimmed colors are better.
        // Let's create a hybrid:
        let quoteColors = LayoutColors(
            text: quote.textColor,
            secondaryText: quote.textColor.withAlphaComponent(0.8),
            background: quote.backgroundColor
        )
        
        return MarkdownTheme(
            baseFont: baseFont,
            colors: quoteColors,
            headings: headings, // Headings usually keep their relative size/weight
            code: newCode,
            quote: quote, // Nested quotes stay same for now
            lists: newLists,
            tables: newTables,
            images: newImages,
            paragraphSpacing: paragraphSpacing,
            linkColor: linkColor.withAlphaComponent(0.8),
            separatorColor: separatorColor.withAlphaComponent(0.6)
        )
    }
}
