import XCTest
@testable import STXMarkdownView

@MainActor
final class MarkdownViewIntegrationTests: XCTestCase {
    private var sut: MarkdownView!
    private var hostWindow: UIWindow!

    override func setUp() {
        super.setUp()
        hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sut = MarkdownView(theme: makeTestTheme())
        sut.frame = CGRect(x: 0, y: 0, width: 342, height: 600)
        sut.preferredMaxLayoutWidth = 342
        sut.isScrollEnabled = false
        sut.backgroundColor = .white
        hostWindow.addSubview(sut)
        hostWindow.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    override func tearDown() {
        sut = nil
        hostWindow = nil
        super.tearDown()
    }

    func testRenderEmptyMarkdown() {
        sut.markdown = ""
        sut.layoutIfNeeded()
        XCTAssertTrue(sut.attributedText == nil || sut.attributedText?.length == 0)
    }

    func testRenderPlainText() {
        sut.markdown = "Hello Markdown"
        sut.layoutIfNeeded()
        XCTAssertTrue(sut.attributedText?.string.hasPrefix("Hello Markdown") ?? false)
    }

    func testRenderHeadings() {
        sut.markdown = "# Title\n\n## Subtitle\n\n### Section"
        sut.layoutIfNeeded()
        XCTAssertFalse(sut.attributedText?.string.isEmpty ?? true)
    }

    func testRenderCodeBlockCreatesAttachment() {
        sut.markdown = """
        ```swift
        print("Hello")
        ```
        """
        sut.layoutIfNeeded()
        let hasCodeBlock = sut.attachmentViews.values.contains { $0.view is CodeBlockView }
        XCTAssertTrue(hasCodeBlock)
    }

    func testRenderTableCreatesAttachment() {
        sut.markdown = """
        | A | B |
        | --- | --- |
        | 1 | 2 |
        """
        sut.layoutIfNeeded()
        let hasTable = sut.attachmentViews.values.contains { $0.view is MarkdownTableView }
        XCTAssertTrue(hasTable)
    }

    func testRenderQuoteCreatesAttachment() {
        sut.markdown = "> Quote line\n> Another line"
        sut.layoutIfNeeded()
        let hasQuote = sut.attachmentViews.values.contains { $0.view is QuoteView }
        XCTAssertTrue(hasQuote)
    }

    func testRenderImageCreatesAttachment() throws {
        let fileURL = try writeTempImageFile()
        sut.imageHandler = MockImageHandler()
        sut.markdown = "![Image](\(fileURL.absoluteString))"
        sut.layoutIfNeeded()
        let hasImage = sut.attachmentViews.values.contains { $0.view is MarkdownImageView }
        XCTAssertTrue(hasImage)
    }

    func testRenderMixedContent() {
        sut.markdown = """
        # Header
        > Quote

        ```swift
        print("Hi")
        ```

        | A | B |
        | --- | --- |
        | 1 | 2 |
        """
        sut.layoutIfNeeded()
        XCTAssertGreaterThan(sut.attachmentViews.count, 0)
    }

    func testIntrinsicContentSizeCalculation() {
        sut.markdown = "This is a longer line of markdown text that should wrap and increase height."
        sut.layoutIfNeeded()
        XCTAssertGreaterThan(sut.intrinsicContentSize.height, 0)
    }

    func testPreferredMaxLayoutWidthApplied() {
        sut.preferredMaxLayoutWidth = 300
        sut.markdown = "Line one\nLine two"
        sut.layoutIfNeeded()
        XCTAssertEqual(sut.textContainer.size.width, 300, accuracy: 0.5)
    }
}
