import XCTest
import Markdown
@testable import STXMarkdownView

@MainActor
final class MarkdownParserTests: XCTestCase {
    func testParsePlainTextCreatesAttributedString() {
        let parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "Hello")
        var mutableParser = parser
        let result = mutableParser.parse(document)
        XCTAssertTrue(result.attributedString.string.contains("Hello"))
        XCTAssertEqual(result.attachments.count, 0)
    }

    func testHeadingAppliesTextAndNewline() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "# Title")
        let result = parser.parse(document)
        XCTAssertTrue(result.attributedString.string.contains("Title"))
        XCTAssertTrue(result.attributedString.string.hasSuffix("\n"))
    }

    func testBoldAndItalicAttributesApplied() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "**Bold** *Italic*")
        let result = parser.parse(document)
        XCTAssertTrue(result.attributedString.string.contains("Bold"))
        XCTAssertTrue(result.attributedString.string.contains("Italic"))
    }

    func testInlineCodeAttributesApplied() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "Use `code`")
        let result = parser.parse(document)
        XCTAssertTrue(result.attributedString.string.contains("code"))
        let range = (result.attributedString.string as NSString).range(of: "code")
        let background = result.attributedString.attribute(.backgroundColor, at: range.location, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(background)
    }

    func testStrikethroughAttributeApplied() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "~~gone~~")
        let result = parser.parse(document)
        let range = (result.attributedString.string as NSString).range(of: "gone")
        let strike = result.attributedString.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int
        XCTAssertEqual(strike, NSUnderlineStyle.single.rawValue)
    }

    func testLinkAttributeApplied() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "[Link](https://example.com)")
        let result = parser.parse(document)
        let range = (result.attributedString.string as NSString).range(of: "Link")
        let link = result.attributedString.attribute(.link, at: range.location, effectiveRange: nil) as? String
        XCTAssertEqual(link, "https://example.com")
    }

    func testUnorderedListAddsMarkers() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "- One\n- Two")
        let result = parser.parse(document)
        XCTAssertTrue(result.attributedString.string.contains("-\tOne"))
        XCTAssertTrue(result.attributedString.string.contains("-\tTwo"))
    }

    func testOrderedListAddsMarkers() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "1. One\n2. Two")
        let result = parser.parse(document)
        XCTAssertTrue(result.attributedString.string.contains("1.\tOne"))
        XCTAssertTrue(result.attributedString.string.contains("2.\tTwo"))
    }

    func testImageCreatesAttachment() {
        let parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200, imageHandler: MockImageHandler())
        let document = Document(parsing: "![alt](https://example.com/image.png)")
        var mutableParser = parser
        let result = mutableParser.parse(document)
        XCTAssertEqual(result.attachments.count, 1)
    }

    func testHorizontalRuleCreatesAttachment() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "---")
        let result = parser.parse(document)
        XCTAssertEqual(result.attachments.count, 1)
    }

    func testCodeBlockCreatesAttachment() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 200)
        let document = Document(parsing: "```swift\nprint(\"hi\")\n```")
        let result = parser.parse(document)
        XCTAssertEqual(result.attachments.count, 1)
    }

    func testTableCreatesAttachment() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 240)
        let document = Document(parsing: "| A | B |\n|---|---|\n| 1 | 2 |")
        let result = parser.parse(document)
        XCTAssertEqual(result.attachments.count, 1)
    }

    func testTableCellParseCacheInvalidatesWhenLinkDestinationChanges() throws {
        let cache = TableCellSizeCache()
        let firstMarkdown = "| Link |\n|---|\n| [docs](https://example.com/a) |"
        let secondMarkdown = "| Link |\n|---|\n| [docs](https://example.com/b) |"

        var firstParser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 320, tableSizeCache: cache)
        let firstResult = firstParser.parse(Document(parsing: firstMarkdown))
        XCTAssertEqual(firstResult.attachments.count, 1)

        var secondParser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 320, tableSizeCache: cache)
        let secondResult = secondParser.parse(Document(parsing: secondMarkdown))
        XCTAssertEqual(secondResult.attachments.count, 1)

        let firstTableView = try XCTUnwrap(firstResult.attachments.values.first?.view as? MarkdownTableView)
        let secondTableView = try XCTUnwrap(secondResult.attachments.values.first?.view as? MarkdownTableView)

        let firstCell = try XCTUnwrap(firstTableView.rowAttributedTextsForTesting.first?.first)
        let secondCell = try XCTUnwrap(secondTableView.rowAttributedTextsForTesting.first?.first)

        func firstLinkString(in attributedText: NSAttributedString) -> String? {
            var extractedLink: String?
            attributedText.enumerateAttribute(
                .link,
                in: NSRange(location: 0, length: attributedText.length),
                options: []
            ) { value, _, stop in
                if let url = value as? URL {
                    extractedLink = url.absoluteString
                    stop.pointee = true
                } else if let link = value as? String {
                    extractedLink = link
                    stop.pointee = true
                }
            }
            return extractedLink
        }

        let firstLink = firstLinkString(in: firstCell)
        let secondLink = firstLinkString(in: secondCell)

        XCTAssertEqual(firstLink, "https://example.com/a")
        XCTAssertEqual(secondLink, "https://example.com/b")
    }

    func testBlockQuoteCreatesAttachment() {
        var parser = MarkdownParser(theme: makeTestTheme(), maxLayoutWidth: 240)
        let document = Document(parsing: "> Quote")
        let result = parser.parse(document)
        XCTAssertEqual(result.attachments.count, 1)
    }
}
