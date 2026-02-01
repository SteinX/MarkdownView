import XCTest
@testable import STXMarkdownView

@MainActor
final class MarkdownTableViewTests: XCTestCase {
    func testComputeLayoutRespectsMinColumnWidth() {
        let theme = makeTestTheme()
        let header = NSAttributedString(string: "Header")
        let rows = [[NSAttributedString(string: "Cell")]]
        let result = MarkdownTableView.computeLayout(headers: [header], rows: rows, theme: theme, maxWidth: 20, cache: nil)
        XCTAssertGreaterThanOrEqual(result.columnWidths.first ?? 0, theme.tables.minColumnWidth)
    }

    func testUpdateAdjustsContentSize() {
        let theme = makeTestTheme()
        let header = (NSAttributedString(string: "H"), [Int: AttachmentInfo]())
        let rows = [[(NSAttributedString(string: "Cell"), [Int: AttachmentInfo]())]]
        let view = MarkdownTableView(headers: [header], rows: rows, theme: theme, maxLayoutWidth: 120, precomputedLayout: nil, sizeCache: nil)
        let newHeader = (NSAttributedString(string: "Header"), [Int: AttachmentInfo]())
        view.update(headers: [newHeader], rows: rows, theme: theme, maxLayoutWidth: 120, precomputedLayout: nil, sizeCache: nil)
        XCTAssertGreaterThan(view.intrinsicContentSize.width, 0)
    }
}
