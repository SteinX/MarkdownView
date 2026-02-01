import UIKit
#if canImport(Highlightr)
import Highlightr
#endif

// MARK: - Code Block View
public class CodeBlockView: UIView, Reusable {
    private let headerView = UIView()
    private let languageLabel = UILabel()
    private let scrollView = UIScrollView() // Container for content
    private let label = UILabel()
    private let copyButton = UIButton(type: .system)
    private var code: String
    private var language: String?
    private var isHighlighted: Bool = false
    private var currentTheme: MarkdownTheme?
    
    public init(code: String, language: String?, theme: MarkdownTheme) {
        self.code = code
        self.language = language
        super.init(frame: .zero)
        backgroundColor = theme.code.backgroundColor
        layer.cornerRadius = 6
        clipsToBounds = true
        
        // Header
        headerView.backgroundColor = theme.code.headerColor
        headerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Language Label
        languageLabel.font = theme.code.languageLabelFont
        languageLabel.textColor = theme.code.languageLabelColor
        if let lang = language, !lang.isEmpty {
            languageLabel.text = Self.formatLanguageName(lang)
        }
        languageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // ScrollView & Label
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        // Only allow scrolling direction based on content, but generally we want horizontal for code
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.showsVerticalScrollIndicator = false
        
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        configureCodeLabel(code: code, language: language, theme: theme)
        
        // Copy Button (Resized to 20x20 visual, touch area stays same or use padding)
        copyButton.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        copyButton.tintColor = .systemGray
        copyButton.addTarget(self, action: #selector(copyCode), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(headerView)
        headerView.addSubview(languageLabel)
        headerView.addSubview(copyButton)
        
        addSubview(scrollView)
        scrollView.addSubview(label)
        
        // Basic Constraints
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 34), // Slightly shorter header for compact look
            
            languageLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            languageLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 12),
            languageLabel.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor, constant: -8),
            
            // Smaller copy button
            copyButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            copyButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -8),
            copyButton.widthAnchor.constraint(equalToConstant: 20),
            copyButton.heightAnchor.constraint(equalToConstant: 20),
            
            // ScrollView fills available space below header
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Label inside ScrollView
            label.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -12),
            
            // Fit Frame height to Content height (disable vertical scrolling, force view expansion)
             label.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor, constant: -24)
        ])
        
        // Scrollable Logic
        if theme.code.isScrollable {
            // Horizontal scroll enabled: Label width is NOT constrained to view width
            // Allowing label to expand naturally horizontally
        } else {
            // Wrapping enabled: Label width constrained to ScrollView frame width (minus padding)
             let widthConstraint = label.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -24)
             widthConstraint.priority = .required
             widthConstraint.isActive = true
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    @objc private func copyCode() {
        UIPasteboard.general.string = code
        // Feedback animation could be added here
    }
    
    private func configureCodeLabel(code: String, language: String?, theme: MarkdownTheme) {
        // Try Highlightr if language is specified
        if let lang = language, !lang.isEmpty {
            if let highlightedCode = Self.highlightCode(code, language: lang, themeName: theme.code.syntaxHighlightTheme, codeFont: theme.code.font) {
                label.attributedText = highlightedCode
                return
            }
        }
        
        // Fallback to plain text
        label.text = code
        label.font = theme.code.font
        label.textColor = theme.code.textColor
    }
    
    /// Format language identifiers into readable names (e.g., "javascript" → "JavaScript")
    private static func formatLanguageName(_ language: String) -> String {
        let lower = language.lowercased()
        
        // 1. Common acronyms that should be all-caps
        let acronyms: Set<String> = ["html", "css", "sql", "php", "json", "xml", "yaml", "yml", "bash", "sh", "cpp"]
        if acronyms.contains(lower) {
            if lower == "cpp" { return "C++" }
            return lower.uppercased()
        }
        
        // 2. Special mappings for specific styling
        let specialMappings: [String: String] = [
            "js": "JavaScript",
            "javascript": "JavaScript",
            "ts": "TypeScript",
            "typescript": "TypeScript",
            "cs": "C#",
            "csharp": "C#",
            "objc": "Objective-C",
            "objectivec": "Objective-C",
            "vb": "Visual Basic"
        ]
        
        if let mapped = specialMappings[lower] {
            return mapped
        }
        
        // 3. Generic fallback: Capitalized (e.g., "python" -> "Python", "swift" -> "Swift")
        return language.capitalized
    }
    
    /// Highlight code using Highlightr library
    /// Returns nil if Highlightr is not available or highlighting fails
    private static func highlightCode(_ code: String, language: String, themeName: String, codeFont: UIFont) -> NSAttributedString? {
        #if canImport(Highlightr)

        guard let highlightr = Highlightr() else {
             MarkdownLogger.error(.codeBlock, "Failed to initialize Highlightr")
             return nil
        }
        highlightr.setTheme(to: themeName)
        highlightr.theme.codeFont = codeFont
        
        if let result = highlightr.highlight(code, as: language, fastRender: true) {
             return result
        } else {
             MarkdownLogger.error(.codeBlock, "Highlightr failed to highlight code for language: \(language)")
             return nil
        }
        #else
        MarkdownLogger.warning(.codeBlock, "Highlightr module is NOT imported. Syntax highlighting is disabled.")
        return nil
        #endif
    }
    
    // MARK: - Reuse Support
    
    /// Update the view with new content - optimized to skip redundant highlighting
    /// - Parameters:
    ///   - code: The code content to display
    ///   - language: Optional language identifier
    ///   - theme: Markdown theme for styling
    ///   - shouldHighlight: Whether to apply syntax highlighting (false for unclosed blocks during streaming)
    public func update(code: String, language: String?, theme: MarkdownTheme, shouldHighlight: Bool) {
        // Check if we can skip update (zero-cost reuse)
        if self.code == code && 
           self.language == language && 
           self.isHighlighted == shouldHighlight {
            MarkdownLogger.verbose(.codeBlock, "update skipped, content unchanged")
            return
        }
        
        MarkdownLogger.debug(.codeBlock, "update lang=\(language ?? "none"), highlight=\(shouldHighlight), lines=\(code.components(separatedBy: "\n").count)")
        
        // Update stored state
        self.code = code
        self.language = language
        self.isHighlighted = shouldHighlight
        self.currentTheme = theme
        
        // Update UI
        backgroundColor = theme.code.backgroundColor
        headerView.backgroundColor = theme.code.headerColor
        
        if let lang = language, !lang.isEmpty {
            languageLabel.text = Self.formatLanguageName(lang)
        } else {
            languageLabel.text = ""
        }
        
        // Configure code with or without highlighting
        if shouldHighlight {
            configureCodeLabel(code: code, language: language, theme: theme)
        } else {
            // Skip expensive highlighting for unclosed blocks
            label.text = code
            label.font = theme.code.font
            label.textColor = theme.code.textColor
        }
    }
    
    /// Prepare view for reuse - reset to clean state
    public func prepareForReuse() {
        code = ""
        language = nil
        isHighlighted = false
        currentTheme = nil
        label.attributedText = nil
        label.text = nil
        languageLabel.text = ""
    }
}

public struct CodeBlockContentKey: AttachmentContentKey {
    public let codeHash: Int
    public let codeLength: Int
    public let language: String?
    public let shouldHighlight: Bool
    public let width: CGFloat
    public let isInsideQuote: Bool

    public init(
        codeHash: Int,
        codeLength: Int,
        language: String?,
        shouldHighlight: Bool,
        width: CGFloat,
        isInsideQuote: Bool
    ) {
        self.codeHash = codeHash
        self.codeLength = codeLength
        self.language = language
        self.shouldHighlight = shouldHighlight
        self.width = width
        self.isInsideQuote = isInsideQuote
    }
}
