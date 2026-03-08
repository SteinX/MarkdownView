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

    func testThemeUpdateRerendersWithoutMarkdownOrWidthChange() {
        sut.markdown = "**Bold**"
        sut.layoutIfNeeded()

        let originalResult = sut.lastRenderedResult
        XCTAssertNotNil(originalResult)

        sut.theme = makeDarkTestTheme()
        sut.layoutIfNeeded()

        let updatedResult = sut.lastRenderedResult
        XCTAssertNotNil(updatedResult)
        XCTAssertFalse(originalResult === updatedResult, "Theme changes should invalidate render skip cache and produce a fresh render result")
    }

    func testImageHandlerUpdateRerendersWithoutMarkdownOrWidthChange() throws {
        let fileURL = try writeTempImageFile()
        sut.markdown = "![Image](\(fileURL.absoluteString))"
        sut.layoutIfNeeded()

        let originalResult = sut.lastRenderedResult
        XCTAssertNotNil(originalResult)

        let newHandler = MockImageHandler()
        sut.imageHandler = newHandler
        sut.layoutIfNeeded()

        let updatedResult = sut.lastRenderedResult
        XCTAssertNotNil(updatedResult)
        XCTAssertFalse(originalResult === updatedResult, "Image handler changes should invalidate render skip cache and produce a fresh render result")
    }

    // MARK: - findCommonPrefixLength Correctness (Wave 1)

    func testFindCommonPrefixLength_detectsDivergenceBetweenSamplePoints() {
        let text = String(repeating: "a", count: 100)
        let font = UIFont.systemFont(ofSize: 14)

        let a = NSMutableAttributedString(string: text, attributes: [.font: font])
        let b = NSMutableAttributedString(string: text, attributes: [.font: font])
        b.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 5, length: 1))

        let result = sut.findCommonPrefixLength(a, b)
        XCTAssertEqual(result, 5, "Must detect attribute divergence at position 5 (between 8-sample points)")
    }

    func testFindCommonPrefixLength_identicalStrings() {
        let text = "Hello World"
        let font = UIFont.systemFont(ofSize: 14)
        let a = NSAttributedString(string: text, attributes: [.font: font])
        let b = NSAttributedString(string: text, attributes: [.font: font])

        let result = sut.findCommonPrefixLength(a, b)
        XCTAssertEqual(result, text.count)
    }

    func testFindCommonPrefixLength_emptyStrings() {
        let a = NSAttributedString(string: "")
        let b = NSAttributedString(string: "")
        XCTAssertEqual(sut.findCommonPrefixLength(a, b), 0)
    }

    func testFindCommonPrefixLength_differentTextAtStart() {
        let a = NSAttributedString(string: "Hello", attributes: [.font: UIFont.systemFont(ofSize: 14)])
        let b = NSAttributedString(string: "World", attributes: [.font: UIFont.systemFont(ofSize: 14)])
        XCTAssertEqual(sut.findCommonPrefixLength(a, b), 0)
    }

    func testFindCommonPrefixLength_attributeDivergenceAtStart() {
        let text = "Hello"
        let a = NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 14)])
        let b = NSAttributedString(string: text, attributes: [.font: UIFont.boldSystemFont(ofSize: 14)])
        XCTAssertEqual(sut.findCommonPrefixLength(a, b), 0)
    }

    func testFindCommonPrefixLength_partialTextMatch() {
        let a = NSAttributedString(string: "Hello World", attributes: [.font: UIFont.systemFont(ofSize: 14)])
        let b = NSAttributedString(string: "Hello Swift", attributes: [.font: UIFont.systemFont(ofSize: 14)])
        XCTAssertEqual(sut.findCommonPrefixLength(a, b), 6)
    }

    func testFindCommonPrefixLength_multipleAttributeRunsDiverge() {
        let text = String(repeating: "x", count: 200)
        let font = UIFont.systemFont(ofSize: 14)

        let a = NSMutableAttributedString(string: text, attributes: [.font: font])
        a.addAttribute(.foregroundColor, value: UIColor.blue, range: NSRange(location: 50, length: 50))

        let b = NSMutableAttributedString(string: text, attributes: [.font: font])
        b.addAttribute(.foregroundColor, value: UIColor.red, range: NSRange(location: 50, length: 50))

        let result = sut.findCommonPrefixLength(a, b)
        XCTAssertEqual(result, 50, "Prefix is identical for first 50 chars, diverges at attribute run boundary")
    }

    // MARK: - Block Descriptors (Wave 3)

    func testBlockDescriptors_countMatchesAttachments() {
        sut.markdown = """
        # Title

        ```swift
        let x = 1
        ```

        > A quote

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        sut.layoutIfNeeded()

        let descriptors = sut.lastRenderedResult!.blockDescriptors
        let attachmentCount = sut.lastRenderedResult!.attachments.count
        XCTAssertEqual(descriptors.count, attachmentCount)
        XCTAssertGreaterThanOrEqual(descriptors.count, 3, "Should have code, quote, and table attachments")
    }

    func testBlockDescriptors_orderedByCharPosition() {
        sut.markdown = """
        ```
        first
        ```

        > second

        ```
        third
        ```
        """
        sut.layoutIfNeeded()

        let descriptors = sut.lastRenderedResult!.blockDescriptors
        XCTAssertEqual(descriptors.count, 3)
        for i in 0..<descriptors.count {
            XCTAssertEqual(descriptors[i].blockIndex, i)
        }
    }

    func testIsAppendOnly_trueWhenNewBlocksAppended() {
        let old = [
            BlockDescriptor(contentKey: AnyHashable("code1"), blockIndex: 0),
            BlockDescriptor(contentKey: AnyHashable("table1"), blockIndex: 1),
        ]
        let new = [
            BlockDescriptor(contentKey: AnyHashable("code1"), blockIndex: 0),
            BlockDescriptor(contentKey: AnyHashable("table1"), blockIndex: 1),
            BlockDescriptor(contentKey: AnyHashable("quote1"), blockIndex: 2),
        ]
        XCTAssertTrue(isAppendOnly(old: old, new: new))
    }

    func testIsAppendOnly_falseWhenBlockInsertedInMiddle() {
        let old = [
            BlockDescriptor(contentKey: AnyHashable("code1"), blockIndex: 0),
            BlockDescriptor(contentKey: AnyHashable("table1"), blockIndex: 1),
        ]
        let new = [
            BlockDescriptor(contentKey: AnyHashable("code1"), blockIndex: 0),
            BlockDescriptor(contentKey: AnyHashable("quote1"), blockIndex: 1),
            BlockDescriptor(contentKey: AnyHashable("table1"), blockIndex: 2),
        ]
        XCTAssertFalse(isAppendOnly(old: old, new: new))
    }

    func testIsAppendOnly_falseWhenBlockDeleted() {
        let old = [
            BlockDescriptor(contentKey: AnyHashable("code1"), blockIndex: 0),
            BlockDescriptor(contentKey: AnyHashable("table1"), blockIndex: 1),
        ]
        let new = [
            BlockDescriptor(contentKey: AnyHashable("code1"), blockIndex: 0),
        ]
        XCTAssertFalse(isAppendOnly(old: old, new: new))
    }

    func testIsAppendOnly_trueWhenOldIsEmpty() {
        let old: [BlockDescriptor] = []
        let new = [
            BlockDescriptor(contentKey: AnyHashable("code1"), blockIndex: 0),
        ]
        XCTAssertTrue(isAppendOnly(old: old, new: new))
    }

    func testIsAppendOnly_trueWhenBothEmpty() {
        XCTAssertTrue(isAppendOnly(old: [], new: []))
    }

    func testIsAppendOnly_trueWhenIdentical() {
        let descriptors = [
            BlockDescriptor(contentKey: AnyHashable("code1"), blockIndex: 0),
            BlockDescriptor(contentKey: AnyHashable("table1"), blockIndex: 1),
        ]
        XCTAssertTrue(isAppendOnly(old: descriptors, new: descriptors))
    }

    func testNoOrphanedSubviews_afterRender() {
        sut.markdown = """
        # Title

        ```swift
        let x = 1
        ```

        > Quote text

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        sut.layoutIfNeeded()

        let firstRenderViews = sut.lastRenderedResult!.attachments.values.map { $0.view }
        let subviewSet = Set(sut.subviews.map { ObjectIdentifier($0) })

        for view in firstRenderViews {
            XCTAssertTrue(subviewSet.contains(ObjectIdentifier(view)),
                          "Attachment view not added as subview: \(type(of: view))")
        }

        sut.markdown = "# Simple"
        sut.layoutIfNeeded()

        let currentSubviews = Set(sut.subviews.map { ObjectIdentifier($0) })
        for view in firstRenderViews {
            XCTAssertFalse(currentSubviews.contains(ObjectIdentifier(view)),
                           "Stale attachment view not removed: \(type(of: view))")
        }
    }

    // MARK: - Identity Preservation (Wave 4)

    func testPreservedViewIdentity_appendPreservesExistingCodeBlock() {
        sut.markdown = """
        ```swift
        let x = 1
        ```
        """
        sut.layoutIfNeeded()

        let codeView = sut.attachmentViews.values.first { $0.view is CodeBlockView }!
        let originalViewID = ObjectIdentifier(codeView.view)

        // Append a table — code block content unchanged, should preserve view object
        sut.markdown = """
        ```swift
        let x = 1
        ```

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        sut.layoutIfNeeded()

        let codeViewAfter = sut.attachmentViews.values.first { $0.view is CodeBlockView }!
        XCTAssertEqual(ObjectIdentifier(codeViewAfter.view), originalViewID,
                       "Same contentKey should preserve view object identity across renders")
    }

    func testPreservedViewIdentity_changedContentGetsNewView() {
        sut.markdown = """
        ```swift
        let x = 1
        ```
        """
        sut.layoutIfNeeded()

        let codeView = sut.attachmentViews.values.first { $0.view is CodeBlockView }!
        let originalViewID = ObjectIdentifier(codeView.view)

        // Change code content — different contentKey, should get new view
        sut.markdown = """
        ```swift
        let y = 2
        ```
        """
        sut.layoutIfNeeded()

        let codeViewAfter = sut.attachmentViews.values.first { $0.view is CodeBlockView }!
        XCTAssertNotEqual(ObjectIdentifier(codeViewAfter.view), originalViewID,
                          "Changed content should produce new view object")
    }

    func testPreservedViewIdentity_multipleAttachmentsAllPreserved() {
        sut.markdown = """
        ```swift
        let x = 1
        ```

        > Quote text here

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        sut.layoutIfNeeded()

        let oldViewIDs = sut.attachmentViews.values.map { ObjectIdentifier($0.view) }
        let oldCount = sut.attachmentViews.count
        XCTAssertGreaterThanOrEqual(oldCount, 3, "Should have code, quote, and table")

        // Append more content — all existing blocks unchanged
        sut.markdown = """
        ```swift
        let x = 1
        ```

        > Quote text here

        | A | B |
        |---|---|
        | 1 | 2 |

        Some trailing text added.
        """
        sut.layoutIfNeeded()

        let newViewIDs = Set(sut.attachmentViews.values.map { ObjectIdentifier($0.view) })
        for oldID in oldViewIDs {
            XCTAssertTrue(newViewIDs.contains(oldID),
                          "All original views should be preserved when their content is unchanged")
        }
    }

    func testNoOrphanedSubviews_afterDiffedRender() {
        // Render with multiple attachments
        sut.markdown = """
        ```swift
        let x = 1
        ```

        > Quote

        | A | B |
        |---|---|
        | 1 | 2 |
        """
        sut.layoutIfNeeded()

        // Append content (diff render)
        sut.markdown = """
        ```swift
        let x = 1
        ```

        > Quote

        | A | B |
        |---|---|
        | 1 | 2 |

        ```python
        print("hello")
        ```
        """
        sut.layoutIfNeeded()

        // Every attachment view must be a subview
        let subviewIDs = Set(sut.subviews.map { ObjectIdentifier($0) })
        for info in sut.attachmentViews.values {
            XCTAssertTrue(subviewIDs.contains(ObjectIdentifier(info.view)),
                          "Attachment view not a subview after diff render: \(type(of: info.view))")
        }

        // No stale subviews (every attachment subview should be in attachmentViews)
        let attachmentViewIDs = Set(sut.attachmentViews.values.map { ObjectIdentifier($0.view) })
        for subview in sut.subviews {
            // Skip non-attachment subviews (UITextView has internal subviews)
            if subview is CodeBlockView || subview is MarkdownTableView || subview is QuoteView || subview is MarkdownImageView || subview is HorizontalRuleView {
                XCTAssertTrue(attachmentViewIDs.contains(ObjectIdentifier(subview)),
                              "Stale attachment subview found: \(type(of: subview))")
            }
        }
    }

    func testDiffedRender_duplicateContentKeys_noOrphan() {
        // Two identical code blocks
        sut.markdown = """
        ```swift
        let x = 1
        ```

        Some text

        ```swift
        let x = 1
        ```
        """
        sut.layoutIfNeeded()
        let firstCount = sut.attachmentViews.count

        // Append text — both code blocks unchanged
        sut.markdown = """
        ```swift
        let x = 1
        ```

        Some text

        ```swift
        let x = 1
        ```

        More text added.
        """
        sut.layoutIfNeeded()

        // Verify no orphaned attachment subviews
        let attachmentViewIDs = Set(sut.attachmentViews.values.map { ObjectIdentifier($0.view) })
        for subview in sut.subviews {
            if subview is CodeBlockView || subview is MarkdownTableView || subview is QuoteView {
                XCTAssertTrue(attachmentViewIDs.contains(ObjectIdentifier(subview)),
                              "Orphaned subview after duplicate contentKey diff: \(type(of: subview))")
            }
        }

        // Should still have same number of code blocks
        let codeBlockCount = sut.attachmentViews.values.filter { $0.view is CodeBlockView }.count
        XCTAssertGreaterThanOrEqual(codeBlockCount, 2, "Should preserve both code blocks")
    }

    func testWidthChange_producedDifferentContentKeys() {
        sut.preferredMaxLayoutWidth = 300
        sut.markdown = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        sut.layoutIfNeeded()
        let descriptors300 = sut.lastRenderedResult!.blockDescriptors

        sut.preferredMaxLayoutWidth = 200
        sut.markdown = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """
        sut.layoutIfNeeded()
        let descriptors200 = sut.lastRenderedResult!.blockDescriptors

        XCTAssertEqual(descriptors300.count, 1)
        XCTAssertEqual(descriptors200.count, 1)
        XCTAssertNotEqual(descriptors300[0].contentKey, descriptors200[0].contentKey,
                          "Width is part of contentKey, so different widths produce different keys")
    }
}
