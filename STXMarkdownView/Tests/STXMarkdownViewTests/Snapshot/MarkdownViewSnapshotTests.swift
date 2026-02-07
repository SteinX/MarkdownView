import XCTest
import SnapshotTesting
@testable import STXMarkdownView

@MainActor
final class MarkdownViewSnapshotTests: XCTestCase {
    private var sut: MarkdownView!
    private var hostWindow: UIWindow!

    override func setUp() {
        super.setUp()
        isRecording = false
        hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sut = MarkdownView(theme: makeTestTheme())
        sut.frame = CGRect(x: 0, y: 0, width: 342, height: 600)
        sut.preferredMaxLayoutWidth = 342
        sut.isScrollEnabled = false
        sut.backgroundColor = .white
        hostWindow.addSubview(sut)
        hostWindow.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }

    override func tearDown() {
        sut = nil
        hostWindow = nil
        super.tearDown()
    }

    func testSnapshotHeadings() {
        sut.markdown = "# Heading\n\n## Subheading\n\n### Section"
        assertMarkdownSnapshot(named: "Headings")
    }

    func testSnapshotCodeBlockSwift() {
        sut.markdown = """
        ```swift
        func hello() {
            print("Hello")
        }
        ```
        """
        assertMarkdownSnapshot(named: "CodeBlock_Swift")
    }

    func testSnapshotCodeBlockPlain() {
        sut.markdown = """
        ```
        plain text
        ```
        """
        assertMarkdownSnapshot(named: "CodeBlock_Plain")
    }

    func testSnapshotTableSimple() {
        sut.markdown = """
        | A | B | C |
        | --- | --- | --- |
        | 1 | 2 | 3 |
        | 4 | 5 | 6 |
        """
        assertMarkdownSnapshot(named: "Table_Simple")
    }

    func testSnapshotQuoteNested() {
        sut.markdown = "> Quote line\n> > Nested quote"
        assertMarkdownSnapshot(named: "Quote_Nested")
    }

    func testSnapshotListMixed() {
        sut.markdown = """
        1. First
        2. Second
           - Nested A
           - Nested B
        """
        assertMarkdownSnapshot(named: "List_Mixed")
    }

    func testSnapshotComplexContent() {
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
        assertMarkdownSnapshot(named: "ComplexContent")
    }

    func testSnapshotDarkMode() {
        sut.backgroundColor = .black
        sut.theme = makeDarkTestTheme()
        sut.markdown = "# Dark\n\n`inline` **bold**"
        assertMarkdownSnapshot(named: "DarkMode")
    }

    private func assertMarkdownSnapshot(named name: String, file: StaticString = #file, testName: String = #function) {
        sut.layoutIfNeeded()
        let size = sut.intrinsicContentSize
        sut.frame = CGRect(origin: .zero, size: CGSize(width: 342, height: max(200, size.height)))
        sut.layoutIfNeeded()
        assertSnapshot(of: sut, as: .image, named: name, file: file, testName: testName)
    }
}
