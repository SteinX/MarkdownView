import UIKit
import Markdown

struct MyMarkdownItem {
    let attributedString: NSAttributedString
    let attachments: [Int: UIView] // Character Index -> View
}

struct MyMarkdownParser: MarkupWalker {
    private var attributedString = NSMutableAttributedString()
    private var attachments: [Int: UIView] = [:]
    private let theme: MarkdownTheme
    private let maxLayoutWidth: CGFloat
    private var listDepth = 0
    
    init(theme: MarkdownTheme, maxLayoutWidth: CGFloat) {
        self.theme = theme
        self.maxLayoutWidth = maxLayoutWidth
    }
    
    mutating func parse(_ document: Document) -> MyMarkdownItem {
        visit(document)
        return MyMarkdownItem(attributedString: attributedString, attachments: attachments)
    }
    
    // MARK: - Visitors
    
    mutating func visitHeading(_ heading: Heading) {
        let level = heading.level
        let font = theme.headingFonts[min(level - 1, theme.headingFonts.count - 1)]
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.textColor
        ]
        
        let text = heading.myPlainText
        attributedString.append(NSAttributedString(string: text + "\n", attributes: attributes))
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) {
        descendInto(paragraph)
        attributedString.append(NSAttributedString(string: "\n\n"))
    }
    
    mutating func visitText(_ text: Text) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.baseFont,
            .foregroundColor: theme.textColor
        ]
        attributedString.append(NSAttributedString(string: text.string, attributes: attributes))
    }
    
    mutating func visitStrong(_ strong: Strong) {
        let attributes: [NSAttributedString.Key: Any] = [.font: theme.boldFont]
        let start = attributedString.length
        descendInto(strong)
        attributedString.addAttributes(attributes, range: NSRange(location: start, length: attributedString.length - start))
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) {
        let attributes: [NSAttributedString.Key: Any] = [.font: theme.italicFont]
        let start = attributedString.length
        descendInto(emphasis)
        attributedString.addAttributes(attributes, range: NSRange(location: start, length: attributedString.length - start))
    }
    
    // MARK: - Lists
    
    mutating func visitOrderedList(_ orderedList: OrderedList) {
        listDepth += 1
        descendInto(orderedList)
        listDepth -= 1
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        listDepth += 1
        descendInto(unorderedList)
        listDepth -= 1
    }
    
    mutating func visitListItem(_ listItem: ListItem) {
        let indent: CGFloat = 20.0 * CGFloat(max(0, listDepth - 1))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = indent
        paragraphStyle.headIndent = indent + 12 // Indent text after bullet
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.baseFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let bullet = "• "
        attributedString.append(NSAttributedString(string: bullet, attributes: attributes))
        
        descendInto(listItem)
        attributedString.append(NSAttributedString(string: "\n"))
    }

    // MARK: - Complex Blocks (Attachments)
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let code = codeBlock.code
        let view = CodeBlockView(code: code, theme: theme)
        
        // Pre-calculate height
        let size = view.systemLayoutSizeFitting(
            CGSize(width: maxLayoutWidth, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        view.frame = CGRect(origin: .zero, size: size)
        view.translatesAutoresizingMaskIntoConstraints = false
        insertAttachment(view: view, size: size)
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        let text = blockQuote.myPlainText
        let attrText = NSAttributedString(string: text, attributes: [.font: theme.italicFont, .foregroundColor: theme.textColor])
        
        let view = QuoteView(text: attrText, theme: theme)
        let size = view.systemLayoutSizeFitting(
            CGSize(width: maxLayoutWidth, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        view.frame = CGRect(origin: .zero, size: size)
        view.translatesAutoresizingMaskIntoConstraints = false
        insertAttachment(view: view, size: size)
    }
    
    mutating func visitTable(_ table: Table) {
        // 1. Extract Data
        let headers: [NSAttributedString] = table.head.cells.map { cell in
             var parser = InlineParser(theme: theme, baseFont: theme.boldFont)
             parser.visit(cell)
             return parser.attributedString
        }
        
        let rows: [[NSAttributedString]] = table.body.rows.map { row in
            row.cells.map { cell in
                var parser = InlineParser(theme: theme, baseFont: theme.baseFont)
                parser.visit(cell)
                return parser.attributedString
            }
        }

        guard !headers.isEmpty else {
            return
        }
        
        // 2. Calculate Layout
        let size = MarkdownTableView.computedSize(
            headers: headers,
            rows: rows,
            theme: theme,
            maxWidth: maxLayoutWidth
        )
        
        // 3. Create View
        let view = MarkdownTableView(
            headers: headers,
            rows: rows,
            theme: theme
        )
        
        view.frame = CGRect(origin: .zero, size: size)
        
        insertAttachment(view: view, size: size)
    }
    
    // MARK: - Helper
    
    private mutating func insertAttachment(view: UIView, size: CGSize) {
        // Create transparent placeholder image
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)
        
        if attributedString.length > 0 {
            attributedString.append(NSAttributedString(string: "\n"))
        }
        
        let location = attributedString.length
        attributedString.append(NSAttributedString(attachment: attachment))
        attachments[location] = view
        
        attributedString.append(NSAttributedString(string: "\n"))
    }
}

struct InlineParser: MarkupWalker {
    var attributedString = NSMutableAttributedString()
    let theme: MarkdownTheme
    let baseFont: UIFont
    
    init(theme: MarkdownTheme, baseFont: UIFont) {
        self.theme = theme
        self.baseFont = baseFont
    }
    
    mutating func visitText(_ text: Text) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: theme.textColor
        ]
        attributedString.append(NSAttributedString(string: text.string, attributes: attributes))
    }
    
    mutating func visitStrong(_ strong: Strong) {
        let start = attributedString.length
        descendInto(strong)
        let range = NSRange(location: start, length: attributedString.length - start)
        attributedString.addAttribute(.font, value: theme.boldFont, range: range)
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) {
        let start = attributedString.length
        descendInto(emphasis)
        let range = NSRange(location: start, length: attributedString.length - start)
        attributedString.addAttribute(.font, value: theme.italicFont, range: range)
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        let attributes: [NSAttributedString.Key: Any] = [
             .font: theme.codeFont,
             .backgroundColor: theme.codeBackgroundColor,
             .foregroundColor: theme.codeTextColor
        ]
        attributedString.append(NSAttributedString(string: inlineCode.code, attributes: attributes))
    }
    
    mutating func defaultVisit(_ markup: Markup) {
        descendInto(markup)
    }
}

// Extension to get plain text from Markup
extension Markup {
    var myPlainText: String {
        var walker = MyPlainTextWalker()
        walker.visit(self)
        return walker.text
    }
}

struct MyPlainTextWalker: MarkupWalker {
    var text = ""
    mutating func visitText(_ text: Text) {
        self.text += text.string
    }
    mutating func defaultVisit(_ markup: Markup) {
        descendInto(markup)
    }
}
