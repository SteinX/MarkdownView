import UIKit
import Markdown

// MARK: - Helper Extension for Fonts
extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else {
            return self
        }
        return UIFont(descriptor: descriptor, size: 0) // 0 means keep original size
    }
}

// MARK: - Internal Data Structures

struct MarkdownParseResult {
    let attributedString: NSAttributedString
    let attachments: [Int: UIView] // Character Index -> View
}

// MARK: - Main Parser

struct MarkdownParser: MarkupWalker {
    private var attributedString = NSMutableAttributedString()
    private var attachments: [Int: UIView] = [:]
    private let theme: MarkdownTheme
    private let maxLayoutWidth: CGFloat
    private var listDepth = 0
    private var currentTextColor: UIColor
    private let imageHandler: MarkdownImageHandler
    private let isInsideQuote: Bool
    
    init(theme: MarkdownTheme, maxLayoutWidth: CGFloat, imageHandler: MarkdownImageHandler = DefaultImageHandler(), isInsideQuote: Bool = false) {
        self.theme = theme
        self.maxLayoutWidth = maxLayoutWidth
        self.currentTextColor = theme.colors.text
        self.imageHandler = imageHandler
        self.isInsideQuote = isInsideQuote
    }
    
    mutating func parse(_ document: Document) -> MarkdownParseResult {
        visit(document)
        return MarkdownParseResult(attributedString: attributedString, attachments: attachments)
    }
    
    // MARK: - Visitors
    
    mutating func visitHeading(_ heading: Heading) {
        let level = heading.level
        let fonts = theme.headings.fonts
        let spacings = theme.headings.spacings
        
        let font = fonts[min(level - 1, fonts.count - 1)]
        let spacing = spacings[min(level - 1, spacings.count - 1)]
        
        // Use current indentation (if in list) but override spacing for heading
        let paragraphStyle = currentParagraphStyle(spacing: spacing)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: currentTextColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let text = heading.plainText
        attributedString.append(NSAttributedString(string: text + "\n", attributes: attributes))
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) {
        // DETECT: Image-only paragraph (treat as Block Image)
        if paragraph.childCount == 1, let image = paragraph.child(at: 0) as? Image {
             visitImage(image, asBlock: true)
             return
        }
        
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
            .foregroundColor: currentTextColor
        ]
        attributedString.append(NSAttributedString(string: text.string, attributes: attributes))
    }
    
    mutating func visitStrong(_ strong: Strong) {
        let boldFont = theme.baseFont.withTraits(.traitBold)
        let attributes: [NSAttributedString.Key: Any] = [.font: boldFont]
        let start = attributedString.length
        descendInto(strong)
        attributedString.addAttributes(attributes, range: NSRange(location: start, length: attributedString.length - start))
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) {
        let italicFont = theme.baseFont.withTraits(.traitItalic)
        let attributes: [NSAttributedString.Key: Any] = [.font: italicFont]
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
    
    /// Tracks whether we are processing content that should be aligned with the text of the list item,
    /// rather than the marker. This is true for subsequent paragraphs/blocks within a single list item.
    private var shouldAlignToListContent = false
    
    mutating func visitOrderedList(_ orderedList: OrderedList) {
        let previousAlignState = shouldAlignToListContent
        shouldAlignToListContent = false
        
        listDepth += 1
        listStack.append(ListContext(type: .ordered, index: 1))
        descendInto(orderedList)
        listStack.removeLast()
        listDepth -= 1
        
        shouldAlignToListContent = previousAlignState
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) {
        let previousAlignState = shouldAlignToListContent
        shouldAlignToListContent = false
        
        listDepth += 1
        listStack.append(ListContext(type: .unordered, index: 0))
        descendInto(unorderedList)
        listStack.removeLast()
        listDepth -= 1
        
        shouldAlignToListContent = previousAlignState
    }
    
    mutating func visitListItem(_ listItem: ListItem) {
        guard let context = listStack.last else { return }
        
        let style = currentParagraphStyle()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: theme.baseFont,
            .foregroundColor: currentTextColor,
            .paragraphStyle: style
        ]
        
        // Marker
        let marker: String
        switch context.type {
        case .ordered:
             if let checkbox = listItem.checkbox {
                 marker = getCheckboxMarker(checkbox)
             } else {
                marker = getOrderedMarker(depth: listDepth, index: context.index)
             }
            // Increment index for next item
            if let lastIndex = listStack.indices.last {
                listStack[lastIndex].index += 1
            }
        case .unordered:
            if let checkbox = listItem.checkbox {
                 marker = getCheckboxMarker(checkbox)
            } else {
                let bullets = theme.lists.bulletMarkers
                let bulletIndex = max(0, listDepth - 1) % bullets.count
                marker = bullets[bulletIndex]
            }
        }
        
        if let checkbox = listItem.checkbox {
            // Render Checkbox Image
            let image = checkbox == .checked ? (theme.lists.checkboxCheckedImage ?? UIImage()) : (theme.lists.checkboxUncheckedImage ?? UIImage())
            let tintColor = theme.lists.checkboxColor
            
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(tintColor, renderingMode: .alwaysTemplate)
            
            // Alignment strategy:
            let font = theme.baseFont
            let checkboxSize = font.pointSize
            let yOffset = (font.ascender + font.descender - checkboxSize) / 2.0
            attachment.bounds = CGRect(x: 0, y: yOffset, width: checkboxSize, height: checkboxSize)
            
            let attrStr = NSMutableAttributedString(attachment: attachment)
            attrStr.addAttributes(attributes, range: NSRange(location: 0, length: attrStr.length))
            attributedString.append(attrStr)
            
            attributedString.append(NSAttributedString(string: "\t", attributes: attributes))
        } else {
            // Text Marker
            attributedString.append(NSAttributedString(string: marker + "\t", attributes: attributes))
        }
        
        // Content
        let previousAlignState = shouldAlignToListContent
        
        for (index, child) in listItem.children.enumerated() {
            shouldAlignToListContent = (index > 0)
            visit(child)
        }
        
        shouldAlignToListContent = previousAlignState
    }
    
    // MARK: - Helpers
    
    private func currentParagraphStyle(spacing: CGFloat? = nil) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        
        if listDepth > 0 {
            let indentStep: CGFloat = theme.lists.indentStep
            let markerIndent = indentStep * CGFloat(listDepth - 1)
            let textIndent = markerIndent + theme.lists.markerSpacing
            
            style.firstLineHeadIndent = shouldAlignToListContent ? textIndent : markerIndent
            style.headIndent = textIndent
            style.paragraphSpacing = spacing ?? theme.lists.spacing
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
    
    private func getCheckboxMarker(_ checkbox: Checkbox) -> String {
        return "" // Handled inside visitListItem
    }

    // MARK: - Complex Blocks (Attachments)
    
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) {
        let availableWidth = max(0, maxLayoutWidth - currentIndentationWidth)
        let view = HorizontalRuleView(theme: theme, width: availableWidth)
        insertAttachment(view: view, size: view.frame.size, isBlock: true)
    }
    
    mutating func visitImage(_ image: Image) {
        visitImage(image, asBlock: false)
    }
    
    mutating func visitImage(_ image: Image, asBlock: Bool) {
        guard let source = image.source, let url = URL(string: source) else { return }
        
        let availableWidth = max(0, maxLayoutWidth - currentIndentationWidth)
        
        let size: CGSize
        if asBlock {
             let height = availableWidth * 0.5625
             size = CGSize(width: availableWidth, height: height)
        } else {
             let side = theme.images.inlineSize
             size = CGSize(width: side, height: side)
        }
        
        let view = MarkdownImageView(url: url, imageHandler: imageHandler, theme: theme, isDimmed: isInsideQuote)
        view.frame = CGRect(origin: .zero, size: size)
        
        insertAttachment(view: view, size: size, isBlock: asBlock)
    }
    
    private var currentIndentationWidth: CGFloat {
        guard listDepth > 0 else { return 0 }
        let indentStep = theme.lists.indentStep
        let markerIndent = indentStep * CGFloat(listDepth - 1)
        return markerIndent + theme.lists.markerSpacing
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let code = codeBlock.code
        let language = codeBlock.language
        let view = CodeBlockView(code: code, language: language, theme: theme)
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let availableWidth = max(0, maxLayoutWidth - currentIndentationWidth)
        
        let size = view.systemLayoutSizeFitting(
            CGSize(width: availableWidth, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: UILayoutPriority.required,
            verticalFittingPriority: UILayoutPriority.fittingSizeLevel
        )
        
        let finalSize = CGSize(width: availableWidth, height: size.height)
        view.frame = CGRect(origin: .zero, size: finalSize)
        view.translatesAutoresizingMaskIntoConstraints = true
        insertAttachment(view: view, size: finalSize, isBlock: true)
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        let padding: CGFloat = theme.quote.padding * 2 // Roughly padding left + padding right + borders
        
        let availableWidth = max(0, maxLayoutWidth - currentIndentationWidth)
        
        let childTheme = theme.quoted
        var childParser = MarkdownParser(theme: childTheme, maxLayoutWidth: availableWidth - padding, imageHandler: imageHandler, isInsideQuote: true)
        
        for child in blockQuote.children {
            childParser.visit(child)
        }
        
        let attributedText = childParser.attributedString
        let attachments = childParser.attachments
        
        let view = QuoteView(attributedText: attributedText, attachments: attachments, theme: theme)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.preferredMaxLayoutWidth = availableWidth
        
        view.frame = CGRect(x: 0, y: 0, width: availableWidth, height: 1000)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        let size = view.systemLayoutSizeFitting(
            CGSize(width: availableWidth, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        let finalSize = CGSize(width: availableWidth, height: size.height)
        view.frame = CGRect(origin: .zero, size: finalSize)
        view.preferredMaxLayoutWidth = nil
        view.translatesAutoresizingMaskIntoConstraints = true
        insertAttachment(view: view, size: finalSize, isBlock: true)
    }
    
    mutating func visitTable(_ table: Table) {
        func parseCell(_ cell: Markup) -> (NSAttributedString, [Int: UIView]) {
             var parser = InlineParser(theme: theme, baseFont: theme.baseFont, imageHandler: imageHandler, isInsideQuote: isInsideQuote)
             parser.visit(cell)
             return (parser.attributedString, parser.attachments)
        }
        
        var headerItems: [(NSAttributedString, [Int: UIView])] = []
        let boldFont = theme.baseFont.withTraits(.traitBold)
        
        for cell in table.head.cells {
             var parser = InlineParser(theme: theme, baseFont: boldFont, imageHandler: imageHandler, isInsideQuote: isInsideQuote)
             parser.visit(cell)
             headerItems.append((parser.attributedString, parser.attachments))
        }
        
        var rowItems: [[(NSAttributedString, [Int: UIView])]] = []
        for row in table.body.rows {
            var items: [(NSAttributedString, [Int: UIView])] = []
            for cell in row.cells {
                items.append(parseCell(cell))
            }
            rowItems.append(items)
        }

        guard !headerItems.isEmpty else { return }
        
        let availableWidth = max(0, maxLayoutWidth - currentIndentationWidth)
        
        let headerTexts = headerItems.map { $0.0 }
        let rowTexts = rowItems.map { row in row.map { $0.0 } }
        
        let size = MarkdownTableView.computedSize(
            headers: headerTexts,
            rows: rowTexts,
            theme: theme,
            maxWidth: availableWidth
        )
        
        let view = MarkdownTableView(
            headers: headerItems,
            rows: rowItems,
            theme: theme,
            maxLayoutWidth: availableWidth
        )
        
        view.frame = CGRect(origin: .zero, size: size)
        insertAttachment(view: view, size: size, isBlock: true)
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        let attributes: [NSAttributedString.Key: Any] = [
             .font: theme.code.font,
             .backgroundColor: theme.code.backgroundColor,
             .foregroundColor: theme.code.textColor
        ]
        attributedString.append(NSAttributedString(string: inlineCode.code, attributes: attributes))
    }
    
    mutating func visitLink(_ link: Link) {
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.linkColor,
            .link: link.destination ?? ""
        ]
        let start = attributedString.length
        descendInto(link)
        attributedString.addAttributes(attributes, range: NSRange(location: start, length: attributedString.length - start))
    }
    
    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        let attributes: [NSAttributedString.Key: Any] = [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ]
        let start = attributedString.length
        descendInto(strikethrough)
        attributedString.addAttributes(attributes, range: NSRange(location: start, length: attributedString.length - start))
    }
    
    private mutating func insertAttachment(view: UIView, size: CGSize, isBlock: Bool) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)
        
        let paragraphStyle = currentParagraphStyle()
        
        if listDepth > 0 {
            paragraphStyle.firstLineHeadIndent = paragraphStyle.headIndent
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraphStyle
        ]
        
        let location = attributedString.length
        attributedString.append(NSAttributedString(attachment: attachment))
        attributedString.addAttributes(attributes, range: NSRange(location: location, length: 1))
        
        attachments[location] = view
        
        if isBlock {
            attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
        }
    }
}

// MARK: - Inline Parser

struct InlineParser: MarkupWalker {
    var attributedString = NSMutableAttributedString()
    var attachments: [Int: UIView] = [:]
    
    let theme: MarkdownTheme
    let baseFont: UIFont
    let imageHandler: MarkdownImageHandler
    let isInsideQuote: Bool
    
    init(theme: MarkdownTheme, baseFont: UIFont, imageHandler: MarkdownImageHandler? = nil, isInsideQuote: Bool = false) {
        self.theme = theme
        self.baseFont = baseFont
        self.imageHandler = imageHandler ?? DefaultImageHandler()
        self.isInsideQuote = isInsideQuote
    }
    
    mutating func visitText(_ text: Text) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: theme.colors.text
        ]
        attributedString.append(NSAttributedString(string: text.string, attributes: attributes))
    }
    
    mutating func visitImage(_ image: Image) {
        guard let source = image.source, let url = URL(string: source) else { return }
        
        let side = theme.images.inlineSize
        let size = CGSize(width: side, height: side)
        
        let view = MarkdownImageView(url: url, imageHandler: imageHandler, theme: theme, isDimmed: isInsideQuote)
        view.frame = CGRect(origin: .zero, size: size)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        let placeholderImage = renderer.image { _ in }
        
        let attachment = NSTextAttachment()
        attachment.image = placeholderImage
        attachment.bounds = CGRect(origin: .zero, size: size)
        
        let location = attributedString.length
        let attrAttachment = NSMutableAttributedString(attachment: attachment)
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: theme.colors.text
        ]
        attrAttachment.addAttributes(attributes, range: NSRange(location: 0, length: 1))
        
        attributedString.append(attrAttachment)
        attachments[location] = view
    }
    
    mutating func visitStrong(_ strong: Strong) {
        let start = attributedString.length
        descendInto(strong)
        let range = NSRange(location: start, length: attributedString.length - start)
        let boldFont = baseFont.withTraits(.traitBold)
        attributedString.addAttribute(.font, value: boldFont, range: range)
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) {
        let start = attributedString.length
        descendInto(emphasis)
        let range = NSRange(location: start, length: attributedString.length - start)
        let italicFont = baseFont.withTraits(.traitItalic)
        attributedString.addAttribute(.font, value: italicFont, range: range)
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) {
        let attributes: [NSAttributedString.Key: Any] = [
             .font: theme.code.font,
             .backgroundColor: theme.code.backgroundColor,
             .foregroundColor: theme.code.textColor
        ]
        attributedString.append(NSAttributedString(string: inlineCode.code, attributes: attributes))
    }
    
    mutating func visitLink(_ link: Link) {
         let attributes: [NSAttributedString.Key: Any] = [
             .foregroundColor: theme.linkColor
         ]
         let start = attributedString.length
         descendInto(link)
         attributedString.addAttributes(attributes, range: NSRange(location: start, length: attributedString.length - start))
    }
    
    mutating func visitStrikethrough(_ strikethrough: Strikethrough) {
        let attributes: [NSAttributedString.Key: Any] = [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ]
        let start = attributedString.length
        descendInto(strikethrough)
        attributedString.addAttributes(attributes, range: NSRange(location: start, length: attributedString.length - start))
    }
    
    mutating func defaultVisit(_ markup: Markup) {
        descendInto(markup)
    }
}

// MARK: - Plain Text Extractor

extension Markup {
    var plainText: String {
        var walker = PlainTextWalker()
        walker.visit(self)
        return walker.text
    }
}

struct PlainTextWalker: MarkupWalker {
    var text = ""
    mutating func visitText(_ text: Text) {
        self.text += text.string
    }
    mutating func defaultVisit(_ markup: Markup) {
        descendInto(markup)
    }
}
