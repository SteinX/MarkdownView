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
        isRecording = ProcessInfo.processInfo.environment["SNAPSHOT_RECORDING"] == "1"
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
        sut.imageHandler = MockImageHandler()
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

    // MARK: - Enriched Content Scenarios

    func testSnapshotAllHeadingLevels() {
        sut.markdown = """
        # Heading 1
        ## Heading 2
        ### Heading 3
        #### Heading 4
        ##### Heading 5
        ###### Heading 6
        """
        assertMarkdownSnapshot(named: "AllHeadingLevels")
    }

    func testSnapshotInlineFormatting() {
        sut.markdown = """
        This is **bold text** and *italic text*.

        Here is ***bold italic*** combined.

        Some `inline code` in a sentence.

        A [link to example](https://example.com) here.

        Text with ~~strikethrough~~ formatting.

        Mix of **bold with `code`** and *italic with `code`*.
        """
        assertMarkdownSnapshot(named: "InlineFormatting")
    }

    func testSnapshotTaskList() {
        sut.markdown = """
        - [x] Completed task
        - [ ] Incomplete task
        - [x] Another done item
        - [ ] Still pending
          - [x] Nested completed
          - [ ] Nested pending
        """
        assertMarkdownSnapshot(named: "TaskList")
    }

    func testSnapshotHorizontalRule() {
        sut.markdown = """
        Text above the rule.

        ---

        Text between rules.

        ***

        Text below the rule.
        """
        assertMarkdownSnapshot(named: "HorizontalRule")
    }

    func testSnapshotCodeBlockMultiLanguage() {
        sut.markdown = """
        ```rust
        fn main() {
            println!("Hello, Rust!");
        }
        ```

        ```json
        {
          "name": "demo",
          "version": "1.0",
          "tags": ["markdown", "ios"]
        }
        ```

        ```sql
        SELECT u.name, COUNT(o.id) AS order_count
        FROM users u
        LEFT JOIN orders o ON u.id = o.user_id
        GROUP BY u.name
        HAVING order_count > 5;
        ```
        """
        assertMarkdownSnapshot(named: "CodeBlock_MultiLanguage")
    }

    func testSnapshotTableRich() {
        sut.markdown = """
        | Feature | iOS | Android | Web | Status |
        | --- | --- | --- | --- | --- |
        | **Markdown** | ✅ | ✅ | ✅ | Stable |
        | *Streaming* | ✅ | ❌ | ✅ | Beta |
        | `Code blocks` | ✅ | ✅ | ❌ | Alpha |
        | Tables | ✅ | ❌ | ❌ | Dev |
        | Images | ✅ | ✅ | ✅ | Stable |
        """
        assertMarkdownSnapshot(named: "Table_Rich")
    }

    func testSnapshotQuoteWithCodeBlock() {
        sut.markdown = """
        > Here is a quote with embedded code:
        >
        > ```swift
        > let greeting = "Hello, World!"
        > print(greeting)
        > ```
        >
        > The code above prints a greeting.
        """
        assertMarkdownSnapshot(named: "Quote_WithCodeBlock")
    }

    func testSnapshotQuoteWithList() {
        sut.markdown = """
        > **Important notes:**
        >
        > 1. First item in the quote
        > 2. Second item in the quote
        >    - Nested bullet A
        >    - Nested bullet B
        > 3. Third item
        """
        assertMarkdownSnapshot(named: "Quote_WithList")
    }

    func testSnapshotQuoteWithTable() {
        sut.markdown = """
        > **Comparison Table:**
        >
        > | Name | Score |
        > | --- | --- |
        > | Alice | 95 |
        > | Bob | 88 |
        """
        assertMarkdownSnapshot(named: "Quote_WithTable")
    }

    func testSnapshotNestedListsDeep() {
        sut.markdown = """
        1. Top level ordered
           - Second level bullet
             1. Third level ordered
                - Fourth level bullet
             2. Back to third
           - Another second level
        2. Top level again
           1. Ordered nested
              - Deep bullet
        """
        assertMarkdownSnapshot(named: "NestedLists_Deep")
    }

    func testSnapshotRichDocument() {
        sut.markdown = """
        # Project Overview

        This is a **comprehensive** demo of all supported *Markdown* elements.

        ## Features

        - Headings (all 6 levels)
        - **Bold**, *italic*, and `inline code`
        - [Links](https://example.com) and ~~strikethrough~~

        ### Code Example

        ```swift
        struct ContentView {
            let title: String
            var body: String {
                return "# \\(title)"
            }
        }
        ```

        ### Data Table

        | Metric | Q1 | Q2 | Q3 |
        | --- | --- | --- | --- |
        | Revenue | $1.2M | $1.5M | $1.8M |
        | Users | 10K | 15K | 22K |
        | Growth | 12% | 25% | 47% |

        > **Note:** These numbers are for demonstration purposes only.
        > They do not represent actual data.

        ---

        ## Task List

        - [x] Implement parser
        - [x] Add theme support
        - [ ] Write documentation
        - [ ] Release v1.0

        That's the end of this rich document.
        """
        assertMarkdownSnapshot(named: "RichDocument")
    }

    // MARK: - Theme Switching Tests

    func testSnapshotDarkModeCodeBlock() {
        sut.backgroundColor = .black
        sut.theme = makeDarkTestTheme()
        sut.markdown = """
        ```swift
        func calculate(a: Int, b: Int) -> Int {
            return a + b
        }
        ```
        """
        assertMarkdownSnapshot(named: "DarkMode_CodeBlock")
    }

    func testSnapshotDarkModeTable() {
        sut.backgroundColor = .black
        sut.theme = makeDarkTestTheme()
        sut.markdown = """
        | Name | Role | Status |
        | --- | --- | --- |
        | Alice | Engineer | Active |
        | Bob | Designer | Active |
        | Carol | PM | On Leave |
        """
        assertMarkdownSnapshot(named: "DarkMode_Table")
    }

    func testSnapshotDarkModeQuote() {
        sut.backgroundColor = .black
        sut.theme = makeDarkTestTheme()
        sut.markdown = """
        > This is a blockquote in dark mode.
        >
        > > Nested quote with **bold** and `code`.
        """
        assertMarkdownSnapshot(named: "DarkMode_Quote")
    }

    func testSnapshotDarkModeLists() {
        sut.backgroundColor = .black
        sut.theme = makeDarkTestTheme()
        sut.markdown = """
        1. First ordered item
        2. Second ordered item
           - Nested unordered A
           - Nested unordered B
        3. Third ordered item

        - [x] Completed dark task
        - [ ] Pending dark task
        """
        assertMarkdownSnapshot(named: "DarkMode_Lists")
    }

    func testSnapshotDarkModeRichDocument() {
        sut.backgroundColor = .black
        sut.theme = makeDarkTestTheme()
        sut.markdown = """
        # Dark Rich Document

        Paragraph with **bold**, *italic*, `code`, and [link](https://example.com).

        ```json
        { "theme": "dark", "enabled": true }
        ```

        | Key | Value |
        | --- | --- |
        | Mode | Dark |
        | Contrast | High |

        > A blockquote in the dark.

        ---

        - Item one
        - Item two
          - Nested item
        """
        assertMarkdownSnapshot(named: "DarkMode_RichDocument")
    }

    func testSnapshotCustomThemeLargeFont() {
        let largeTheme = makeCustomLargeFontTheme()
        sut.theme = largeTheme
        sut.markdown = """
        # Large Font Theme

        This tests a **custom theme** with larger base font.

        - Item one
        - Item two

        > A quote in large font.
        """
        assertMarkdownSnapshot(named: "CustomTheme_LargeFont")
    }

    func testThemeSwitchLightToDark() {
        sut.markdown = """
        # Theme Switch Test

        **Bold text** and `inline code`.

        ```swift
        let x = 42
        ```

        | A | B |
        | --- | --- |
        | 1 | 2 |

        > A blockquote.
        """
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        sut.backgroundColor = .black
        sut.theme = makeDarkTestTheme()

        assertMarkdownSnapshot(named: "ThemeSwitch_LightToDark")
    }

    func testThemeSwitchDarkToLight() {
        sut.backgroundColor = .black
        sut.theme = makeDarkTestTheme()
        sut.markdown = """
        # Dark to Light

        Content with **formatting** and `code`.

        > Quote block.
        """
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        sut.backgroundColor = .white
        sut.theme = makeTestTheme()

        assertMarkdownSnapshot(named: "ThemeSwitch_DarkToLight")
    }

    func testThemeSwitchPreservesContent() {
        let markdown = """
        # Preserved Content

        This text should survive theme switching.

        ```swift
        print("still here")
        ```

        | Col A | Col B |
        | --- | --- |
        | Data 1 | Data 2 |
        """
        sut.markdown = markdown
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let textBefore = sut.textStorage.string
        let attachmentCountBefore = sut.attachmentViews.count

        sut.theme = makeDarkTestTheme()
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(sut.textStorage.string, textBefore, "Text content should be preserved after theme switch")
        XCTAssertEqual(sut.attachmentViews.count, attachmentCountBefore, "Attachment count should be preserved after theme switch")
    }

    func testThemeSwitchMultipleRoundTrips() {
        sut.markdown = """
        # Round Trip

        **Bold** and *italic* with `code`.

        > Quote
        """
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let originalText = sut.textStorage.string

        for _ in 0..<2 {
            sut.theme = makeDarkTestTheme()
            sut.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))

            sut.theme = makeTestTheme()
            sut.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        }

        XCTAssertEqual(sut.textStorage.string, originalText, "Content must survive multiple theme round trips")
    }

    func testThemeSwitchReRendersAttachments() {
        sut.markdown = """
        ```swift
        let a = 1
        ```

        > A blockquote

        | X | Y |
        | --- | --- |
        | 1 | 2 |
        """
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let attachmentCountBefore = sut.attachmentViews.count
        XCTAssertGreaterThan(attachmentCountBefore, 0, "Should have attachments before theme switch")

        sut.theme = makeDarkTestTheme()
        sut.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertEqual(
            sut.attachmentViews.count,
            attachmentCountBefore,
            "Attachment count must match after theme switch — all elements should re-render"
        )
    }

    // MARK: - Image layout regression

    func testImageAttachmentPositionedBelowPrecedingContent() {
        sut.markdown = """
        # Heading

        Some paragraph text before the image.

        ![Image](https://example.com/image.png)
        """

        for _ in 0..<5 {
            sut.setNeedsLayout()
            sut.layoutIfNeeded()
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        sut.layoutIfNeeded()

        let imageAttachment = sut.attachmentViews.values.first { $0.view is MarkdownImageView }
        XCTAssertNotNil(imageAttachment, "Expected a MarkdownImageView attachment in the rendered document")
        let yPosition = imageAttachment?.view.frame.origin.y ?? 0
        XCTAssertGreaterThan(
            yPosition, 30,
            "MarkdownImageView is at y=\(yPosition) — expected below heading text (y>30). "
            + "Possible regression: textContainer.size.height reset caused glyph layout truncation."
        )
    }

    func testSnapshotImageAtDocumentEnd() {
        sut.markdown = """
        # Document Title

        Some paragraph text before the image.

        ![Image](https://example.com/image.png)
        """
        assertMarkdownSnapshot(named: "ImageAtDocumentEnd")
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
        CATransaction.flush()
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

private func makeCustomLargeFontTheme() -> MarkdownTheme {
    let baseFont = UIFont.systemFont(ofSize: 20)
    let colors = MarkdownTheme.LayoutColors(
        text: UIColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 1),
        secondaryText: UIColor(red: 0.4, green: 0.35, blue: 0.5, alpha: 1),
        background: UIColor(red: 0.98, green: 0.97, blue: 1, alpha: 1)
    )
    let headings = MarkdownTheme.HeadingTheme(
        fonts: [
            .boldSystemFont(ofSize: 32),
            .boldSystemFont(ofSize: 28),
            .boldSystemFont(ofSize: 24),
            .boldSystemFont(ofSize: 22),
            .boldSystemFont(ofSize: 20),
            .boldSystemFont(ofSize: 18)
        ],
        spacings: [20, 16, 14, 12, 10, 10]
    )
    let code = MarkdownTheme.CodeBlockTheme(
        font: .monospacedSystemFont(ofSize: 16, weight: .regular),
        backgroundColor: UIColor(red: 0.93, green: 0.92, blue: 0.96, alpha: 1),
        textColor: UIColor(red: 0.15, green: 0.1, blue: 0.25, alpha: 1),
        headerColor: UIColor(red: 0.85, green: 0.84, blue: 0.88, alpha: 1),
        languageLabelFont: .systemFont(ofSize: 14, weight: .medium),
        languageLabelColor: UIColor(red: 0.4, green: 0.35, blue: 0.5, alpha: 1),
        syntaxHighlightTheme: "atom-one-light",
        isScrollable: false
    )
    let quote = MarkdownTheme.QuoteTheme(
        textColor: UIColor(red: 0.3, green: 0.25, blue: 0.4, alpha: 1),
        backgroundColor: UIColor(red: 0.95, green: 0.94, blue: 0.98, alpha: 1),
        borderColor: UIColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 1)
    )
    let lists = MarkdownTheme.ListTheme(
        baseFont: baseFont,
        spacing: 6,
        indentStep: 24,
        markerSpacing: 28,
        bulletMarkers: ["•", "◦", "▪"],
        checkboxCheckedImage: nil,
        checkboxUncheckedImage: nil,
        checkboxColor: UIColor(red: 0.4, green: 0.3, blue: 0.7, alpha: 1)
    )
    let tables = MarkdownTheme.TableTheme(
        borderColor: UIColor(red: 0.6, green: 0.55, blue: 0.7, alpha: 1),
        headerColor: UIColor(red: 0.92, green: 0.91, blue: 0.96, alpha: 1),
        minColumnWidth: 50,
        columnDistribution: .automatic
    )
    let images = MarkdownTheme.ImageTheme(
        loadingPlaceholder: nil,
        backgroundColor: UIColor.clear,
        inlineSize: 22
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
        paragraphSpacing: 14,
        linkColor: UIColor(red: 0.4, green: 0.3, blue: 0.8, alpha: 1),
        separatorColor: UIColor(red: 0.7, green: 0.65, blue: 0.8, alpha: 1)
    )
}

private final class MockImageHandler: MarkdownImageHandler {
    func loadImage(url: URL, targetSize: CGSize, imageView: UIImageView, completion: @escaping (UIImage?) -> Void) {
        let size = CGSize(width: max(1, targetSize.width), height: max(1, targetSize.height))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
        }
        completion(image)
    }
}
