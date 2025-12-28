import UIKit

struct MarkdownTheme {
    let baseFont: UIFont
    let codeFont: UIFont
    let boldFont: UIFont
    let italicFont: UIFont
    let headingFonts: [UIFont]
    
    let textColor: UIColor
    let quoteTextColor: UIColor
    let codeBackgroundColor: UIColor
    let codeTextColor: UIColor
    let linkColor: UIColor
    let quoteBackgroundColor: UIColor
    let quoteBorderColor: UIColor
    let separatorColor: UIColor
    let tableBorderColor: UIColor
    let tableHeaderColor: UIColor
    let codeHeaderColor: UIColor
    
    // Spacing
    let paragraphSpacing: CGFloat
    let headingSpacings: [CGFloat]
    let listSpacing: CGFloat
    let listIndentStep: CGFloat
    let listMarkerSpacing: CGFloat
    let bulletMarkers: [String]
    
    static let `default` = MarkdownTheme(
        baseFont: .systemFont(ofSize: 15),
        codeFont: .monospacedSystemFont(ofSize: 13, weight: .regular),
        boldFont: .boldSystemFont(ofSize: 15),
        italicFont: .italicSystemFont(ofSize: 15),
        headingFonts: [
            .boldSystemFont(ofSize: 24),
            .boldSystemFont(ofSize: 20),
            .boldSystemFont(ofSize: 18),
            .boldSystemFont(ofSize: 16),
            .systemFont(ofSize: 16, weight: .bold),
            .systemFont(ofSize: 14, weight: .bold)
        ],
        textColor: .label,
        quoteTextColor: .secondaryLabel,
        codeBackgroundColor: .secondarySystemBackground,
        codeTextColor: .label,
        linkColor: .link,
        quoteBackgroundColor: .systemGray6,
        quoteBorderColor: .systemGray4,
        separatorColor: .separator,
        tableBorderColor: .systemGray4,
        tableHeaderColor: .systemGray5,
        codeHeaderColor: .systemGray5,
        paragraphSpacing: 12,
        headingSpacings: [16, 12, 10, 8, 8, 8],
        listSpacing: 4,
        listIndentStep: 20,
        listMarkerSpacing: 24,
        bulletMarkers: ["•", "◦", "■"]
    )
    
    var quoted: MarkdownTheme {
        var theme = self
        // Create a 'muted' version of the theme
        // We can use the existing init, but since it's a struct with let properties, we need to create a new instance.
        // To make this easier, let's just return a new instance with overrides.
        
        return MarkdownTheme(
            baseFont: baseFont,
            codeFont: codeFont,
            boldFont: boldFont,
            italicFont: italicFont,
            headingFonts: headingFonts,
            textColor: quoteTextColor, // Main text becomes quote text
            quoteTextColor: quoteTextColor,
            codeBackgroundColor: UIColor(white: 0, alpha: 0.05), // Subtle styling for code inside quote
            codeTextColor: quoteTextColor, // Code text matches quote text
            linkColor: linkColor,
            quoteBackgroundColor: quoteBackgroundColor, // Nested quotes?
            quoteBorderColor: quoteBorderColor,
            separatorColor: separatorColor,
            tableBorderColor: tableBorderColor,
            tableHeaderColor: tableHeaderColor,
            codeHeaderColor: codeHeaderColor,
            paragraphSpacing: paragraphSpacing,
            headingSpacings: headingSpacings,
            listSpacing: listSpacing,
            listIndentStep: listIndentStep,
            listMarkerSpacing: listMarkerSpacing,
            bulletMarkers: bulletMarkers
        )
    }
}
