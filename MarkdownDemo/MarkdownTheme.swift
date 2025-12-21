import UIKit

struct MarkdownTheme {
    let baseFont: UIFont
    let codeFont: UIFont
    let boldFont: UIFont
    let italicFont: UIFont
    let headingFonts: [UIFont]
    
    let textColor: UIColor
    let codeBackgroundColor: UIColor
    let codeTextColor: UIColor
    let quoteBackgroundColor: UIColor
    let quoteBorderColor: UIColor
    let separatorColor: UIColor
    let tableBorderColor: UIColor
    let tableHeaderColor: UIColor
    let codeHeaderColor: UIColor
    
    static let `default` = MarkdownTheme(
        baseFont: .systemFont(ofSize: 15),
        codeFont: .monospacedSystemFont(ofSize: 13, weight: .regular),
        boldFont: .boldSystemFont(ofSize: 15),
        italicFont: .italicSystemFont(ofSize: 15),
        headingFonts: [
            .boldSystemFont(ofSize: 22),
            .boldSystemFont(ofSize: 20),
            .boldSystemFont(ofSize: 18),
            .boldSystemFont(ofSize: 16),
            .systemFont(ofSize: 16, weight: .bold),
            .systemFont(ofSize: 14, weight: .bold)
        ],
        textColor: .label,
        codeBackgroundColor: .secondarySystemBackground,
        codeTextColor: .label,
        quoteBackgroundColor: .systemGray6,
        quoteBorderColor: .systemGray4,
        separatorColor: .separator,
        tableBorderColor: .systemGray4,
        tableHeaderColor: .systemGray5,
        codeHeaderColor: .systemGray5
    )
}
