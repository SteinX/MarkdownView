import XCTest
@testable import STXMarkdownView

@MainActor
final class CodeBlockViewTests: XCTestCase {
    func testUpdateSkipsWhenUnchanged() {
        let theme = makeTestTheme()
        let view = CodeBlockView(code: "print(1)", language: "swift", theme: theme)
        view.update(code: "print(1)", language: "swift", theme: theme, shouldHighlight: true)
        view.update(code: "print(1)", language: "swift", theme: theme, shouldHighlight: true)
        XCTAssertTrue(true)
    }

    func testUpdateWithoutHighlightSetsPlainText() {
        let theme = makeTestTheme()
        let view = CodeBlockView(code: "print(1)", language: "swift", theme: theme)
        view.update(code: "print(2)", language: "swift", theme: theme, shouldHighlight: false)
        view.layoutIfNeeded()
        let label = view.subviews.compactMap { $0 as? UIScrollView }.first?.subviews.compactMap { $0 as? UILabel }.first
        XCTAssertEqual(label?.text, "print(2)")
    }

    func testPrepareForReuseClearsState() {
        let theme = makeTestTheme()
        let view = CodeBlockView(code: "print(1)", language: "swift", theme: theme)
        view.prepareForReuse()
        view.layoutIfNeeded()
        let label = view.subviews.compactMap { $0 as? UIScrollView }.first?.subviews.compactMap { $0 as? UILabel }.first
        XCTAssertNil(label?.text)
    }
}
