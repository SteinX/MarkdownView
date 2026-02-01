import XCTest
import Markdown
@testable import STXMarkdownView

@MainActor
final class InlineParserTests: XCTestCase {
    func testInlineParserParsesText() {
        var parser = InlineParser(theme: makeTestTheme(), baseFont: makeTestTheme().baseFont)
        let document = Document(parsing: "Hello")
        parser.visit(document)
        XCTAssertEqual(parser.attributedString.string, "Hello")
    }

    func testInlineParserAddsImageAttachment() {
        var parser = InlineParser(theme: makeTestTheme(), baseFont: makeTestTheme().baseFont, imageHandler: MockImageHandler())
        let document = Document(parsing: "![alt](https://example.com/image.png)")
        parser.visit(document)
        XCTAssertEqual(parser.attachments.count, 1)
    }

    func testInlineParserAppliesLinkColor() {
        let theme = makeTestTheme()
        var parser = InlineParser(theme: theme, baseFont: theme.baseFont)
        let document = Document(parsing: "[Link](https://example.com)")
        parser.visit(document)
        let range = (parser.attributedString.string as NSString).range(of: "Link")
        let color = parser.attributedString.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
        XCTAssertEqual(color, theme.linkColor)
    }

    func testInlineParserAppliesStrikethrough() {
        var parser = InlineParser(theme: makeTestTheme(), baseFont: makeTestTheme().baseFont)
        let document = Document(parsing: "~~gone~~")
        parser.visit(document)
        let range = (parser.attributedString.string as NSString).range(of: "gone")
        let strike = parser.attributedString.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    func testInlineParserAppliesInlineCodeAttributes() {
        var parser = InlineParser(theme: makeTestTheme(), baseFont: makeTestTheme().baseFont)
        let document = Document(parsing: "Use `code`")
        parser.visit(document)
        let range = (parser.attributedString.string as NSString).range(of: "code")
        let background = parser.attributedString.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(background)
    }
}
