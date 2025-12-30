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
    private var currentTextColor: UIColor
    private let imageHandler: MarkdownImageHandler
    private let isInsideQuote: Bool
    
    init(theme: MarkdownTheme, maxLayoutWidth: CGFloat, imageHandler: MarkdownImageHandler = DefaultImageHandler(), isInsideQuote: Bool = false) {
        self.theme = theme
        self.maxLayoutWidth = maxLayoutWidth
        self.currentTextColor = theme.textColor
        self.imageHandler = imageHandler
        self.isInsideQuote = isInsideQuote
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
            .foregroundColor: currentTextColor, // Use currentTextColor to respect Quote theme
            .paragraphStyle: paragraphStyle
        ]
        
        let text = heading.myPlainText
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
        guard var context = listStack.last else { return }
        
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
                let bullets = theme.bulletMarkers
                let bulletIndex = max(0, listDepth - 1) % bullets.count
                marker = bullets[bulletIndex]
            }
        }
        
        if let checkbox = listItem.checkbox {
            // Render Checkbox Image
            let image = checkbox == .checked ? (theme.checkboxCheckedImage ?? UIImage()) : (theme.checkboxUncheckedImage ?? UIImage())
            let tintColor = theme.checkboxColor
            
            let attachment = NSTextAttachment()
            attachment.image = image.withTintColor(tintColor, renderingMode: .alwaysTemplate)
            
            // Alignment strategy:
            // Center the checkbox between font's ascender and descender
            // This creates visual centering with the full line height
            let font = theme.baseFont
            let checkboxSize = font.pointSize
            // (ascender + descender) gives the "visual center" of the line relative to baseline
            // We offset by half the checkbox size to center it
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
        // We manually iterate children to handle indentation for subsequent blocks.
        let previousAlignState = shouldAlignToListContent
        
        for (index, child) in listItem.children.enumerated() {
            // First child (index 0) shares the line with the marker, unless it's a block causing a newline immediately.
            // But generally, the first child's paragraph style should allow the marker (at indent 0) to exist.
            // Subsequent children (index > 0) MUST start at the textual indentation level.
            shouldAlignToListContent = (index > 0)
            visit(child)
        }
        
        shouldAlignToListContent = previousAlignState
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
            
            // If we are deep in the list content (subsequent paragraphs),
            // the first line should also start at the Text Indent.
            // Otherwise (first paragraph), it starts at Marker Indent to accommodate the bullet.
            style.firstLineHeadIndent = shouldAlignToListContent ? textIndent : markerIndent
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

    
    private func getCheckboxMarker(_ checkbox: Checkbox) -> String {
        // We will render the checkbox as an image attachment in the attributed string?
        // Wait, 'marker' is currently a String appended to the attributed string.
        // The current implementation appends `marker + "\t"`.
        // We can return a specific Unicode character or substitute it with an image attachment later?
        // To be safe and compatible with the current loop, let's use a placeholder string,
        // OR better: we can change the logic in visitListItem to handle attributed markers.
        // But for simplicity/robustness:
        // Use a unicode char if available? 
        // ☑ (U+2611) / ☐ (U+2610)
        // But we want to use the Custom Images from Theme.
        
        // Actually, since this function returns String, we can't return an image here.
        // We need to modify visitListItem logic to allow non-string markers.
        // However, for this step, let's return a special UUID/Key or just handle it inside visitListItem.
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
        
        // Size Estimation
        let size: CGSize
        if asBlock {
             // Block Image: Full width, guessed height (e.g. 16:9)
             let height = availableWidth * 0.5625
             size = CGSize(width: availableWidth, height: height)
        } else {
             // Inline Image: use parameterized size from theme
             let side = theme.inlineImageSize
             size = CGSize(width: side, height: side)
        }
        
        let view = MarkdownImageView(url: url, imageHandler: imageHandler, theme: theme, isDimmed: isInsideQuote)
        // Ensure frame is set
        view.frame = CGRect(origin: .zero, size: size)
        
        insertAttachment(view: view, size: size, isBlock: asBlock)
    }
    
    private var currentIndentationWidth: CGFloat {
        guard listDepth > 0 else { return 0 }
        let indentStep = theme.listIndentStep
        let markerIndent = indentStep * CGFloat(listDepth - 1)
        return markerIndent + theme.listMarkerSpacing
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let code = codeBlock.code
        let view = CodeBlockView(code: code, theme: theme)
        // Helper: Use constraints for measurement
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // Adjust width for indentation
        let availableWidth = max(0, maxLayoutWidth - currentIndentationWidth)
        
        let size = view.systemLayoutSizeFitting(
            CGSize(width: availableWidth, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        // Force width to availableWidth to ensure it fills the available horizontal space
        let finalSize = CGSize(width: availableWidth, height: size.height)
        
        view.frame = CGRect(origin: .zero, size: finalSize)
        // Restore for TextKit frame-based layout
        view.translatesAutoresizingMaskIntoConstraints = true
        insertAttachment(view: view, size: finalSize, isBlock: true)
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) {
        // 1. Recursive Parse for Content
        // We reduce the max width to account for the border and padding of the QuoteView
        // Border (4) + Padding Left (12) + Padding Right (8) = 24
        let padding: CGFloat = 24
        
        // Adjust available width for indentation AND internal padding
        let availableWidth = max(0, maxLayoutWidth - currentIndentationWidth)
        
        let childTheme = theme.quoted
        var childParser = MyMarkdownParser(theme: childTheme, maxLayoutWidth: availableWidth - padding, imageHandler: imageHandler, isInsideQuote: true)
        
        // BlockQuote children are usually paragraphs, lists, etc.
        // We iterate and visit them with the child parser.
        // Note: BlockQuote is a container, so we can't just `descendInto`.
        // We need to parse its children as a separate document fragment or just visit them.
        
        for child in blockQuote.children {
            childParser.visit(child)
        }
        
        let attributedText = childParser.attributedString
        let attachments = childParser.attachments
        
        // 2. Create Quote View
        let view = QuoteView(attributedText: attributedText, attachments: attachments, theme: theme)
        // Helper: Use constraints for measurement
        view.translatesAutoresizingMaskIntoConstraints = false
        
        // CRITICAL: Force explicit width constraint on the inner text view.
        // This ensures text wraps correctly during systemLayoutSizeFitting.
        view.preferredMaxLayoutWidth = availableWidth
        
        // Force layout pass with safe large height to prime the text container
        view.frame = CGRect(x: 0, y: 0, width: availableWidth, height: 1000)
        view.setNeedsLayout()
        view.layoutIfNeeded()
        
        // 3. Layout
        let size = view.systemLayoutSizeFitting(
            CGSize(width: availableWidth, height: UIView.layoutFittingExpandedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        
        // Force width to availableWidth to ensure it fills the available horizontal space
        let finalSize = CGSize(width: availableWidth, height: size.height)
        
        view.frame = CGRect(origin: .zero, size: finalSize)
        // Restore for TextKit frame-based layout
        view.translatesAutoresizingMaskIntoConstraints = true
        insertAttachment(view: view, size: finalSize, isBlock: true)
    }
    
    mutating func visitTable(_ table: Table) {
        // 1. Extract Data
        
        // Helper to run InlineParser and get (String, Attachments)
        func parseCell(_ cell: Markup) -> (NSAttributedString, [Int: UIView]) {
             var parser = InlineParser(theme: theme, baseFont: theme.baseFont, imageHandler: imageHandler, isInsideQuote: isInsideQuote)
             parser.visit(cell)
             return (parser.attributedString, parser.attachments)
        }
        
        // Header
        var headerItems: [(NSAttributedString, [Int: UIView])] = []
        for cell in table.head.cells {
             var parser = InlineParser(theme: theme, baseFont: theme.boldFont, imageHandler: imageHandler, isInsideQuote: isInsideQuote)
             parser.visit(cell)
             headerItems.append((parser.attributedString, parser.attachments))
        }
        
        // Body
        var rowItems: [[(NSAttributedString, [Int: UIView])]] = []
        for row in table.body.rows {
            var items: [(NSAttributedString, [Int: UIView])] = []
            for cell in row.cells {
                items.append(parseCell(cell))
            }
            rowItems.append(items)
        }

        guard !headerItems.isEmpty else {
            return
        }
        
        // Adjust width for indentation
        let availableWidth = max(0, maxLayoutWidth - currentIndentationWidth)
        
        // 2. Calculate Layout
        // We only care about text for layout sizing usually, but if there's an image attachment, 
        // the NSAttributedString has a placeholder character with the attachment bounds.
        // MarkdownTableView.computedSize uses boundingRect, which respects attachment bounds.
        
        let headerTexts = headerItems.map { $0.0 }
        let rowTexts = rowItems.map { row in row.map { $0.0 } }
        
        let size = MarkdownTableView.computedSize(
            headers: headerTexts,
            rows: rowTexts,
            theme: theme,
            maxWidth: availableWidth
        )
        
        // 3. Create View
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
             .font: theme.codeFont,
             .backgroundColor: theme.codeBackgroundColor,
             .foregroundColor: theme.codeTextColor
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
    
    // MARK: - Helper
    
    private mutating func insertAttachment(view: UIView, size: CGSize, isBlock: Bool) {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in }
        
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: size)
        
        // Use current indentation style for attachments too
        let paragraphStyle = currentParagraphStyle()
        
        // Fix: If inside a list, the attachment itself (which is a block) should align with the TEXT, not the MARKER.
        // Standard currentParagraphStyle sets firstLineHeadIndent = Marker Position.
        // We override this for the Attachment line to be headIndent (Text Position).
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

// Keep InlineParser as is...
// We must update visitHeading and visitParagraph to use currentParagraphStyle via replacement below:


struct InlineParser: MarkupWalker {
    var attributedString = NSMutableAttributedString()
    var attachments: [Int: UIView] = [:]
    
    let theme: MarkdownTheme
    let baseFont: UIFont
    let imageHandler: MarkdownImageHandler
    let isInsideQuote: Bool
    
    // Default imageHandler if initialized without one? But we should pass it.
    // We add an init that is compatible or update calls.
    // The previous init didn't take handler. We need to update existing calls (if any outside visitTable).
    // Luckily InlineParser is private/internal mostly.
    
    init(theme: MarkdownTheme, baseFont: UIFont, imageHandler: MarkdownImageHandler? = nil, isInsideQuote: Bool = false) {
        self.theme = theme
        self.baseFont = baseFont
        self.imageHandler = imageHandler ?? DefaultImageHandler()
        self.isInsideQuote = isInsideQuote
    }
    
    mutating func visitText(_ text: Text) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: theme.textColor
        ]
        attributedString.append(NSAttributedString(string: text.string, attributes: attributes))
    }
    
    mutating func visitImage(_ image: Image) {
        guard let source = image.source, let url = URL(string: source) else { return }
        
        // Inline Image - use parameterized size from theme
        let side = theme.inlineImageSize
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
        
        // Apply styling to ensure layout (line height) is calculated consistently with text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: theme.textColor
        ]
        attrAttachment.addAttributes(attributes, range: NSRange(location: 0, length: 1))
        
        attributedString.append(attrAttachment)
        
        attachments[location] = view
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
    
    mutating func visitLink(_ link: Link) {
         let attributes: [NSAttributedString.Key: Any] = [
             .foregroundColor: theme.linkColor,
             // Note: NSTextView/UILabel might handle links differently, but usually .link is enough
             // For static rendering in table we might just color it blue.
             // If we want it clickable, the rendering Text View needs to support it.
             // But for now, visual representation:
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
