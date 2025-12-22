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
        let spacing = theme.headingSpacings[min(level - 1, theme.headingSpacings.count - 1)]
        
        // Use current indentation (if in list) but override spacing for heading
        let paragraphStyle = currentParagraphStyle(spacing: spacing)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: theme.textColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let text = heading.myPlainText
        attributedString.append(NSAttributedString(string: text + "\n", attributes: attributes))
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) {
        let start = attributedString.length
        descendInto(paragraph)
        let length = attributedString.length - start
        
        // Determine style (list-aware)
        let paragraphStyle = currentParagraphStyle()
        
        // Apply style to the paragraph content
        if length > 0 {
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: start, length: length))
        }
        
        // Append newline with same style
        attributedString.append(NSAttributedString(string: "\n", attributes: [.paragraphStyle: paragraphStyle, .font: theme.baseFont]))
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
    
    private enum ListType {
        case ordered
        case unordered
    }
    
    private struct ListContext {
        let type: ListType
        var index: Int
    }
    
    private var listStack: [ListContext] = []
    
    mutating func visitOrderedList(_ orderedList: OrderedList) {
        listDepth += 1
        listStack.append(ListContext(type: .ordered, index: 1))
        descendInto(orderedList)
        listStack.removeLast()
        listDepth -= 1
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        listDepth += 1
        listStack.append(ListContext(type: .unordered, index: 0))
        descendInto(unorderedList)
        listStack.removeLast()
        listDepth -= 1
    }
    
    mutating func visitListItem(_ listItem: ListItem) {
        guard var context = listStack.last else { return }
        
        let style = currentParagraphStyle()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.baseFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: style
        ]
        
        // Marker
        let marker: String
        switch context.type {
        case .ordered:
            marker = getOrderedMarker(depth: listDepth, index: context.index)
            // Increment index for next item
            if let lastIndex = listStack.indices.last {
                listStack[lastIndex].index += 1
            }
        case .unordered:
            let bullets = theme.bulletMarkers
            let bulletIndex = max(0, listDepth - 1) % bullets.count
            marker = bullets[bulletIndex]
        }
        
        attributedString.append(NSAttributedString(string: marker + "\t", attributes: attributes))
        
        // Content
        // We do NOT apply style to the content range here. 
        // We rely on visitParagraph (and others) using currentParagraphStyle() to match indentation.
        descendInto(listItem)
    }
    
    // MARK: - Helpers
    
    private func currentParagraphStyle(spacing: CGFloat? = nil) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        
        if listDepth > 0 {
            let indentStep: CGFloat = theme.listIndentStep
            // Depth 1: Indent 0 (Marker at 0). Text at `indentStep` + padding.
            // Depth 2: Indent 20.
            
            let markerIndent = indentStep * CGFloat(listDepth - 1)
            
            // Text Indent matches the tab stop.
            let textIndent = markerIndent + theme.listMarkerSpacing
            
            style.firstLineHeadIndent = markerIndent
            style.headIndent = textIndent
            style.paragraphSpacing = spacing ?? theme.listSpacing
            style.tabStops = [NSTextTab(textAlignment: .left, location: textIndent, options: [:])]
        } else {
            style.paragraphSpacing = spacing ?? theme.paragraphSpacing
        }
        
        return style
    }
    
    private func getOrderedMarker(depth: Int, index: Int) -> String {
        let cycle = (depth - 1) % 3
        switch cycle {
        case 0: return "\(index)."
        case 1: return "\(toAlpha(index))."
        case 2: return "\(toRoman(index))."
        default: return "\(index)."
        }
    }
    
    private func toAlpha(_ value: Int) -> String {
        // 1 -> a, 2 -> b
        guard value > 0 else { return "" }
        let unicode = 97 + (value - 1) % 26
        return String(UnicodeScalar(unicode)!)
    }
    
    private func toRoman(_ value: Int) -> String {
        guard value > 0 else { return "\(value)" }
        
        let decimals = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        let numerals = ["m", "cm", "d", "cd", "c", "xc", "l", "xl", "x", "ix", "v", "iv", "i"]
        
        var result = ""
        var number = value
        
        for (index, decimal) in decimals.enumerated() {
            while number >= decimal {
                result += numerals[index]
                number -= decimal
            }
        }
        
        return result
    }

    // MARK: - Complex Blocks (Attachments)
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let code = codeBlock.code
        let view = CodeBlockView(code: code, theme: theme)
        
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
            theme: theme,
            maxLayoutWidth: maxLayoutWidth
        )
        
        view.frame = CGRect(origin: .zero, size: size)
        
        insertAttachment(view: view, size: size)
    }
    
    // MARK: - Helper
    
    private mutating func insertAttachment(view: UIView, size: CGSize) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)
        
        // Use current indentation style for attachments too
        let paragraphStyle = currentParagraphStyle()
        
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]
        
        let location = attributedString.length
        attributedString.append(NSAttributedString(attachment: attachment))
        attributedString.addAttributes(attributes, range: NSRange(location: location, length: 1))
        
        attachments[location] = view
        
        attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
    }
}

// Keep InlineParser as is...
// We must update visitHeading and visitParagraph to use currentParagraphStyle via replacement below:


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
