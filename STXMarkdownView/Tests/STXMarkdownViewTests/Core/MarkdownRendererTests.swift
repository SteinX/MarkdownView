import XCTest
import Markdown
@testable import STXMarkdownView

@MainActor
final class MarkdownRendererTests: XCTestCase {
    func testParseReturnsDocument() {
        let renderer = MarkdownRenderer(theme: makeTestTheme(), imageHandler: MockImageHandler(), maxLayoutWidth: 200)
        let document = renderer.parse("Hello")
        XCTAssertTrue(document is Document)
    }

    func testRenderReturnsAttributedString() {
        let renderer = MarkdownRenderer(theme: makeTestTheme(), imageHandler: MockImageHandler(), maxLayoutWidth: 200)
        let result = renderer.render("Hello **World**")
        XCTAssertTrue(result.attributedString.length > 0)
    }

    func testRenderWithDocument() {
        let renderer = MarkdownRenderer(theme: makeTestTheme(), imageHandler: MockImageHandler(), maxLayoutWidth: 200)
        let document = renderer.parse("# Title\nBody")
        let result = renderer.render(document)
        XCTAssertTrue(result.attributedString.string.contains("Title"))
        XCTAssertTrue(result.attributedString.string.contains("Body"))
    }

    func testCalculateHeightReturnsPositiveValue() {
        let renderer = MarkdownRenderer(theme: makeTestTheme(), imageHandler: MockImageHandler(), maxLayoutWidth: 200)
        let height = renderer.calculateHeight(for: "Line\nLine", width: 120)
        XCTAssertGreaterThan(height, 0)
    }

    func testRenderIncludesAttachmentsForImages() {
        let renderer = MarkdownRenderer(theme: makeTestTheme(), imageHandler: MockImageHandler(), maxLayoutWidth: 200)
        let markdown = "![alt](https://example.com/image.png)"
        let result = renderer.render(markdown)
        XCTAssertEqual(result.attachments.count, 1)
    }

    func testRenderIncludesAttachmentsForHorizontalRule() {
        let renderer = MarkdownRenderer(theme: makeTestTheme(), imageHandler: MockImageHandler(), maxLayoutWidth: 200)
        let markdown = "---"
        let result = renderer.render(markdown)
        XCTAssertEqual(result.attachments.count, 1)
    }

    func testRenderIncludesAttachmentsForCodeBlock() {
        let renderer = MarkdownRenderer(theme: makeTestTheme(), imageHandler: MockImageHandler(), maxLayoutWidth: 200)
        let markdown = "```swift\nprint(\"hi\")\n```"
        let result = renderer.render(markdown)
        XCTAssertEqual(result.attachments.count, 1)
    }
}
