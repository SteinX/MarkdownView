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
    enum SyntaxHighlightTheme: String {
        case agate = "agate"
        case androidstudio = "androidstudio"
        case arduinoLight = "arduino-light"
        case arta = "arta"
        case ascetic = "ascetic"
        case atomOneDark = "atom-one-dark"
        case atomOneLight = "atom-one-light"
        case codepenEmbed = "codepen-embed"
        case colorBrewer = "color-brewer"
        case dark = "dark"
        case darkula = "darkula"
        case docco = "docco"
        case dracula = "dracula"
        case far = "far"
        case foundation = "foundation"
        case github = "github"
        case githubGist = "github-gist"
        case googlecode = "googlecode"
        case grayscale = "grayscale"
        case gruvboxDark = "gruvbox-dark"
        case gruvboxLight = "gruvbox-light"
        case hopscotch = "hopscotch"
        case hybrid = "hybrid"
        case idea = "idea"
        case irBlack = "ir-black"
        case kimbieDark = "kimbie.dark"
        case kimbieLight = "kimbie.light"
        case magula = "magula"
        case monoBlue = "mono-blue"
        case monokai = "monokai"
        case monokaiSublime = "monokai-sublime"
        case obsidian = "obsidian"
        case ocean = "ocean"
        case paraisoDark = "paraiso.dark"
        case paraisoLight = "paraiso.light"
        case purebasic = "purebasic"
        case qtcreatorDark = "qtcreator_dark"
        case qtcreatorLight = "qtcreator_light"
        case railscasts = "railscasts"
        case rainbow = "rainbow"
        case routeros = "routeros"
        case schoolBook = "school-book"
        case solarizedDark = "solarized-dark"
        case solarizedLight = "solarized-light"
        case sunburst = "sunburst"
        case tomorrow = "tomorrow"
        case tomorrowNight = "tomorrow-night"
        case tomorrowNightBlue = "tomorrow-night-blue"
        case tomorrowNightBright = "tomorrow-night-bright"
        case tomorrowNightEighties = "tomorrow-night-eighties"
        case vs = "vs"
        case vs2015 = "vs2015"
        case xcode = "xcode"
        case xt256 = "xt256"
        case zenburn = "zenburn"
    }
    
    let codeLanguageLabelFont: UIFont
    let codeLanguageLabelColor: UIColor
    let syntaxHighlightTheme: SyntaxHighlightTheme
    let codeBlockScrollable: Bool
    
    // Spacing
    let paragraphSpacing: CGFloat
    let headingSpacings: [CGFloat]
    let listSpacing: CGFloat
    let listIndentStep: CGFloat
    let listMarkerSpacing: CGFloat
    let bulletMarkers: [String]
    let checkboxCheckedImage: UIImage?
    let checkboxUncheckedImage: UIImage?
    let checkboxColor: UIColor
    let imageLoadingPlaceholder: UIImage?
    let imageBackgroundColor: UIColor
    let inlineImageSize: CGFloat // Height in points, width is calculated to maintain aspect ratio
    
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
        codeLanguageLabelFont: .systemFont(ofSize: 12, weight: .medium),
        codeLanguageLabelColor: .secondaryLabel,
        syntaxHighlightTheme: .atomOneDark,
        codeBlockScrollable: false,
        paragraphSpacing: 12,
        headingSpacings: [16, 12, 10, 8, 8, 8],
        listSpacing: 4,
        listIndentStep: 20,
        listMarkerSpacing: 24,
        bulletMarkers: ["•", "◦", "■"],
        checkboxCheckedImage: UIImage(systemName: "checkmark.square"),
        checkboxUncheckedImage: UIImage(systemName: "square"),
        checkboxColor: .link,
        imageLoadingPlaceholder: UIImage(systemName: "photo"),
        imageBackgroundColor: .clear,
        inlineImageSize: 20
    )
    
    var quoted: MarkdownTheme {
        return MarkdownTheme(
            baseFont: baseFont,
            codeFont: codeFont,
            boldFont: boldFont,
            italicFont: italicFont,
            headingFonts: headingFonts,
            textColor: quoteTextColor,
            quoteTextColor: quoteTextColor,
            codeBackgroundColor: UIColor(white: 0, alpha: 0.05),
            codeTextColor: quoteTextColor,
            linkColor: linkColor,
            quoteBackgroundColor: quoteBackgroundColor,
            quoteBorderColor: quoteBorderColor,
            separatorColor: separatorColor,
            tableBorderColor: tableBorderColor,
            tableHeaderColor: tableHeaderColor,
            codeHeaderColor: codeHeaderColor,
            codeLanguageLabelFont: codeLanguageLabelFont,
            codeLanguageLabelColor: codeLanguageLabelColor,
            syntaxHighlightTheme: syntaxHighlightTheme,
            codeBlockScrollable: codeBlockScrollable,
            paragraphSpacing: paragraphSpacing,
            headingSpacings: headingSpacings,
            listSpacing: listSpacing,
            listIndentStep: listIndentStep,
            listMarkerSpacing: listMarkerSpacing,
            bulletMarkers: bulletMarkers,
            checkboxCheckedImage: checkboxCheckedImage,
            checkboxUncheckedImage: checkboxUncheckedImage,
            checkboxColor: checkboxColor,
            imageLoadingPlaceholder: imageLoadingPlaceholder,
            imageBackgroundColor: imageBackgroundColor,
            inlineImageSize: inlineImageSize
        )
    }
}
