import XCTest
import SnapshotTesting
import UIKit
@testable import STXMarkdownView

@MainActor
final class MarkdownDemoSnapshotTests: XCTestCase {
    private var sut: MarkdownView!
    private var hostWindow: UIWindow!
    private var hostViewController: UIViewController!

    override func setUp() {
        super.setUp()
        isRecording = false
        hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        hostViewController = UIViewController()
        hostViewController.view.frame = hostWindow.bounds
        hostViewController.view.backgroundColor = .white
        hostWindow.rootViewController = hostViewController
        hostWindow.makeKeyAndVisible()
        sut = MarkdownView(theme: makeTestTheme())
        sut.frame = CGRect(x: 0, y: 0, width: 342, height: 600)
        sut.preferredMaxLayoutWidth = 342
        sut.isScrollEnabled = false
        sut.isOpaque = true
        sut.backgroundColor = .white
        hostViewController.view.addSubview(sut)
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
    }

    override func tearDown() {
        sut = nil
        hostWindow = nil
        hostViewController = nil
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
        sut.preferredMaxLayoutWidth = 342
        sut.textContainer.size = CGSize(width: 342, height: CGFloat.greatestFiniteMagnitude)
        sut.setNeedsLayout()
        hostViewController.view.setNeedsLayout()
        sut.layoutIfNeeded()
        sut.setNeedsLayout()
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        sut.layoutIfNeeded()
        sut.layoutManager.ensureLayout(for: sut.textContainer)
        sut.layoutManager.ensureLayout(forCharacterRange: NSRange(location: 0, length: sut.textStorage.length))
        XCTAssertGreaterThan(sut.textStorage.length, 0, "No rendered text in MarkdownView")
        let size = sut.intrinsicContentSize
        sut.frame = CGRect(origin: .zero, size: CGSize(width: 342, height: max(200, size.height)))
        sut.setNeedsLayout()
        hostViewController.view.setNeedsLayout()
        hostWindow.setNeedsLayout()
        hostViewController.view.layoutIfNeeded()
        hostWindow.layoutIfNeeded()
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        hostViewController.view.layoutIfNeeded()
        hostWindow.layoutIfNeeded()
        sut.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(bounds: sut.bounds)
        let image = renderer.image { context in
            sut.layer.render(in: context.cgContext)
        }
        assertSnapshot(of: image, as: .image, named: name, file: file, testName: testName)
    }
}

private func makeTestTheme() -> MarkdownTheme {
    let baseFont = UIFont.systemFont(ofSize: 14)
    let colors = MarkdownTheme.LayoutColors(
        text: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
        secondaryText: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),
        background: UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    )
    let headings = MarkdownTheme.HeadingTheme(
        fonts: [
            .boldSystemFont(ofSize: 22),
            .boldSystemFont(ofSize: 20),
            .boldSystemFont(ofSize: 18),
            .boldSystemFont(ofSize: 16),
            .boldSystemFont(ofSize: 15),
            .boldSystemFont(ofSize: 14)
        ],
        spacings: [16, 12, 10, 8, 8, 8]
    )
    let code = MarkdownTheme.CodeBlockTheme(
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        backgroundColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1),
        textColor: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
        headerColor: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1),
        languageLabelFont: .systemFont(ofSize: 11, weight: .medium),
        languageLabelColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),
        syntaxHighlightTheme: "atom-one-dark",
        isScrollable: false
    )
    let quote = MarkdownTheme.QuoteTheme(
        textColor: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1),
        backgroundColor: UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
        borderColor: UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    )
    let lists = MarkdownTheme.ListTheme(
        baseFont: baseFont,
        spacing: 4,
        indentStep: 18,
        markerSpacing: 22,
        bulletMarkers: ["-", "*", "+"],
        checkboxCheckedImage: nil,
        checkboxUncheckedImage: nil,
        checkboxColor: UIColor(red: 0, green: 0.4, blue: 0.8, alpha: 1)
    )
    let tables = MarkdownTheme.TableTheme(
        borderColor: UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1),
        headerColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1),
        minColumnWidth: 40,
        columnDistribution: .automatic
    )
    let images = MarkdownTheme.ImageTheme(
        loadingPlaceholder: nil,
        backgroundColor: UIColor.clear,
        inlineSize: 18
    )

    return MarkdownTheme(
        baseFont: baseFont,
        colors: colors,
        headings: headings,
        code: code,
        quote: quote,
        lists: lists,
        tables: tables,
        images: images,
        paragraphSpacing: 10,
        linkColor: UIColor(red: 0, green: 0.4, blue: 0.9, alpha: 1),
        separatorColor: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
    )
}

private func makeDarkTestTheme() -> MarkdownTheme {
    let baseFont = UIFont.systemFont(ofSize: 14)
    let colors = MarkdownTheme.LayoutColors(
        text: UIColor(red: 0.92, green: 0.92, blue: 0.94, alpha: 1),
        secondaryText: UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1),
        background: UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1)
    )
    let headings = MarkdownTheme.HeadingTheme(
        fonts: [
            .boldSystemFont(ofSize: 22),
            .boldSystemFont(ofSize: 20),
            .boldSystemFont(ofSize: 18),
            .boldSystemFont(ofSize: 16),
            .boldSystemFont(ofSize: 15),
            .boldSystemFont(ofSize: 14)
        ],
        spacings: [16, 12, 10, 8, 8, 8]
    )
    let code = MarkdownTheme.CodeBlockTheme(
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        backgroundColor: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1),
        textColor: UIColor(red: 0.9, green: 0.9, blue: 0.92, alpha: 1),
        headerColor: UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1),
        languageLabelFont: .systemFont(ofSize: 11, weight: .medium),
        languageLabelColor: UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1),
        syntaxHighlightTheme: "atom-one-dark",
        isScrollable: false
    )
    let quote = MarkdownTheme.QuoteTheme(
        textColor: UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1),
        backgroundColor: UIColor(red: 0.18, green: 0.18, blue: 0.2, alpha: 1),
        borderColor: UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1)
    )
    let lists = MarkdownTheme.ListTheme(
        baseFont: baseFont,
        spacing: 4,
        indentStep: 18,
        markerSpacing: 22,
        bulletMarkers: ["-", "*", "+"],
        checkboxCheckedImage: nil,
        checkboxUncheckedImage: nil,
        checkboxColor: UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1)
    )
    let tables = MarkdownTheme.TableTheme(
        borderColor: UIColor(red: 0.3, green: 0.3, blue: 0.34, alpha: 1),
        headerColor: UIColor(red: 0.18, green: 0.18, blue: 0.2, alpha: 1),
        minColumnWidth: 40,
        columnDistribution: .automatic
    )
    let images = MarkdownTheme.ImageTheme(
        loadingPlaceholder: nil,
        backgroundColor: UIColor.clear,
        inlineSize: 18
    )

    return MarkdownTheme(
        baseFont: baseFont,
        colors: colors,
        headings: headings,
        code: code,
        quote: quote,
        lists: lists,
        tables: tables,
        images: images,
        paragraphSpacing: 10,
        linkColor: UIColor(red: 0.6, green: 0.8, blue: 1, alpha: 1),
        separatorColor: UIColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1)
    )
}
