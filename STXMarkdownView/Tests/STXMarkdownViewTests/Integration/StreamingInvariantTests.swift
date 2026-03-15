import XCTest
@testable import STXMarkdownView

@MainActor
final class StreamingInvariantTests: XCTestCase {
    private var sut: MarkdownView!
    private var hostWindow: UIWindow!

    override func setUp() {
        super.setUp()
        hostWindow = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        sut = MarkdownView(theme: makeTestTheme())
        sut.frame = CGRect(x: 0, y: 0, width: 342, height: 600)
        sut.preferredMaxLayoutWidth = 342
        sut.isScrollEnabled = false
        hostWindow.addSubview(sut)
        hostWindow.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
    }

    override func tearDown() {
        sut = nil
        hostWindow = nil
        super.tearDown()
    }

    func testFinalizeParity_tableDocument_matchesFreshNonStreamingRender() throws {
        let finalMarkdown = """
        | Name | Value |
        |---|---|
        | Alpha | 100 |
        | Beta | 200 |
        """

        let chunks = [
            "| Name | Value |\n|---|---|\n| Alpha |",
            "| Name | Value |\n|---|---|\n| Alpha | 100 |\n| Beta |",
            finalMarkdown
        ]

        try assertFinalizeParity(chunks: chunks, fullMarkdown: finalMarkdown)
    }

    func testFinalizeParity_codeBlockDocument_matchesFreshNonStreamingRender() throws {
        let finalMarkdown = """
        ```swift
        struct User {
            let id: Int
            let name: String
        }
        print(User(id: 1, name: "stx"))
        ```
        """

        let chunks = [
            "```swift\nstruct User {",
            "```swift\nstruct User {\n    let id: Int\n    let name: String\n}",
            finalMarkdown
        ]

        try assertFinalizeParity(chunks: chunks, fullMarkdown: finalMarkdown)
    }

    func testFinalizeParity_mixedDocument_matchesFreshNonStreamingRender() throws {
        let finalMarkdown = """
        Intro

        | A | B |
        |---|---|
        | 1 | 2 |

        ```swift
        let v = 42
        print(v)
        ```

        Tail
        """

        let chunks = [
            "Intro\n\n| A | B |\n|---|---|\n| 1 |",
            "Intro\n\n| A | B |\n|---|---|\n| 1 | 2 |\n\n```swift\nlet v = 42",
            finalMarkdown
        ]

        try assertFinalizeParity(chunks: chunks, fullMarkdown: finalMarkdown)
    }

    func testDuplicateKeyReconciliation_nonStreamingIdenticalTablesPreserved() {
        let markdown = """
        | A | B |
        |---|---|
        | 1 | 2 |

        Some text between.

        | A | B |
        |---|---|
        | 1 | 2 |
        """

        renderNonStreaming(on: sut, markdown: markdown)

        let tableInfos = sortedAttachmentInfos(from: sut).map(\.1).filter { $0.view is MarkdownTableView }
        XCTAssertGreaterThanOrEqual(sut.attachmentViews.count, 2)
        XCTAssertEqual(tableInfos.count, 2)
        XCTAssertEqual(Set(tableInfos.map { ObjectIdentifier($0.view) }).count, 2)
    }

    func testDuplicateKeyReconciliation_streamingThenFinalizeIdenticalTablesPreserved() {
        let firstTable = """
        | A | B |
        |---|---|
        | 1 | 2 |
        """

        let twoTables = """
        | A | B |
        |---|---|
        | 1 | 2 |

        Some text between.

        | A | B |
        |---|---|
        | 1 | 2 |
        """

        sut.isStreaming = true
        sut.throttleInterval = 0.05
        sut.markdown = firstTable
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()

        sut.markdown = twoTables
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()

        sut.isStreaming = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()

        let tableInfos = sortedAttachmentInfos(from: sut).map(\.1).filter { $0.view is MarkdownTableView }
        XCTAssertGreaterThanOrEqual(sut.attachmentViews.count, 2)
        XCTAssertEqual(tableInfos.count, 2)
        XCTAssertEqual(Set(tableInfos.map { ObjectIdentifier($0.view) }).count, 2)
    }

    func testWidthFreezeInvalidation_tableAttachmentIntrinsicSizeChangesAcrossWidths() throws {
        let markdown = """
        | Column One | Column Two |
        |---|---|
        | this is a long value that should wrap | another long value that should also wrap |
        | secondary row with additional words | more data in the second column |
        """

        sut.preferredMaxLayoutWidth = 342
        sut.frame = CGRect(x: 0, y: 0, width: 342, height: 600)
        renderNonStreaming(on: sut, markdown: markdown)

        let first = try XCTUnwrap(sortedAttachmentInfos(from: sut).map(\.1).first { $0.view is MarkdownTableView })
        let firstSize = first.view.intrinsicContentSize
        let firstKey = try XCTUnwrap(first.contentKey.base as? MarkdownTableContentKey)

        sut.preferredMaxLayoutWidth = 200
        sut.frame = CGRect(x: 0, y: 0, width: 200, height: 600)
        renderNonStreaming(on: sut, markdown: markdown)

        let second = try XCTUnwrap(sortedAttachmentInfos(from: sut).map(\.1).first { $0.view is MarkdownTableView })
        let secondSize = second.view.intrinsicContentSize
        let secondKey = try XCTUnwrap(second.contentKey.base as? MarkdownTableContentKey)

        XCTAssertNotEqual(firstKey.width, secondKey.width)
        XCTAssertTrue(sizeDiffers(firstSize, secondSize))
    }

    func testWidthFreezeInvalidation_codeBlockAttachmentIntrinsicSizeChangesAcrossWidths() throws {
        let markdown = """
        ```swift
        let summary = "alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau upsilon phi chi psi omega alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron pi rho sigma tau"
        let details = "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen twenty"
        print(summary + details)
        ```
        """

        sut.preferredMaxLayoutWidth = 342
        sut.frame = CGRect(x: 0, y: 0, width: 342, height: 600)
        renderNonStreaming(on: sut, markdown: markdown)

        let first = try XCTUnwrap(sortedAttachmentInfos(from: sut).map(\.1).first { $0.view is CodeBlockView })
        let firstContentSize = sut.intrinsicContentSize
        let firstKey = try XCTUnwrap(first.contentKey.base as? CodeBlockContentKey)

        sut.preferredMaxLayoutWidth = 200
        sut.frame = CGRect(x: 0, y: 0, width: 200, height: 600)
        renderNonStreaming(on: sut, markdown: markdown)

        let second = try XCTUnwrap(sortedAttachmentInfos(from: sut).map(\.1).first { $0.view is CodeBlockView })
        let secondContentSize = sut.intrinsicContentSize
        let secondKey = try XCTUnwrap(second.contentKey.base as? CodeBlockContentKey)

        XCTAssertNotEqual(firstKey.width, secondKey.width)
        XCTAssertTrue(sizeDiffers(firstContentSize, secondContentSize))
    }

    func testStreamingTableRowIncrementalSafety_rowCountAndAttachmentCountAcrossTicks() throws {
        let tick1 = "| H1 | H2 |\n|---|---|\n| a | b |"
        let tick2 = "| H1 | H2 |\n|---|---|\n| a | b |\n| c | d |"
        let tick3 = "| H1 | H2 |\n|---|---|\n| a | b |\n| c | d |\n| e | f |"

        sut.isStreaming = true
        sut.throttleInterval = 0.05

        sut.markdown = tick1
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
        XCTAssertEqual(sut.attachmentViews.count, 1)
        let table1 = try XCTUnwrap(sortedAttachmentInfos(from: sut).map(\.1).first?.view as? MarkdownTableView)
        XCTAssertEqual(table1.rowAttributedTextsForTesting.count, 1)

        sut.markdown = tick2
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
        XCTAssertEqual(sut.attachmentViews.count, 1)
        let table2 = try XCTUnwrap(sortedAttachmentInfos(from: sut).map(\.1).first?.view as? MarkdownTableView)
        XCTAssertEqual(table2.rowAttributedTextsForTesting.count, 2)

        sut.markdown = tick3
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
        XCTAssertEqual(sut.attachmentViews.count, 1)
        let table3 = try XCTUnwrap(sortedAttachmentInfos(from: sut).map(\.1).first?.view as? MarkdownTableView)
        XCTAssertEqual(table3.rowAttributedTextsForTesting.count, 3)

        sut.isStreaming = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
    }

    func testStreamingTableRowIncrementalSafety_contentKeyChangesWhenRowsIncrease() throws {
        let tick1 = "| H1 | H2 |\n|---|---|\n| a | b |"
        let tick2 = "| H1 | H2 |\n|---|---|\n| a | b |\n| c | d |"
        let tick3 = "| H1 | H2 |\n|---|---|\n| a | b |\n| c | d |\n| e | f |"

        sut.isStreaming = true
        sut.throttleInterval = 0.05

        sut.markdown = tick1
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
        let key1 = try tableContentKey(from: sut)

        sut.markdown = tick2
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
        let key2 = try tableContentKey(from: sut)

        sut.markdown = tick3
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
        let key3 = try tableContentKey(from: sut)

        XCTAssertNotEqual(key1.dataHash, key2.dataHash)
        XCTAssertNotEqual(key2.dataHash, key3.dataHash)
        XCTAssertNotEqual(key1, key2)
        XCTAssertNotEqual(key2, key3)

        sut.isStreaming = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
    }

    func testStreamingTableRowIncrementalSafety_finalizeKeepsLatestRowCount() throws {
        let tick1 = "| H1 | H2 |\n|---|---|\n| a | b |"
        let tick2 = "| H1 | H2 |\n|---|---|\n| a | b |\n| c | d |"
        let tick3 = "| H1 | H2 |\n|---|---|\n| a | b |\n| c | d |\n| e | f |"

        sut.isStreaming = true
        sut.throttleInterval = 0.05

        sut.markdown = tick1
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()

        sut.markdown = tick2
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()

        sut.markdown = tick3
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()

        sut.isStreaming = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()

        XCTAssertEqual(sut.attachmentViews.count, 1)
        let table = try XCTUnwrap(sortedAttachmentInfos(from: sut).map(\.1).first?.view as? MarkdownTableView)
        XCTAssertEqual(table.rowAttributedTextsForTesting.count, 3)
    }

    private func assertFinalizeParity(chunks: [String], fullMarkdown: String, file: StaticString = #filePath, line: UInt = #line) throws {
        renderStreamingThenFinalize(on: sut, chunks: chunks)
        let baseline = makeComparisonView()
        renderNonStreaming(on: baseline, markdown: fullMarkdown)
        stabilizeLayout(for: sut)
        stabilizeLayout(for: baseline)

        let streamingAttachments = sortedAttachmentInfos(from: sut)
        let baselineAttachments = sortedAttachmentInfos(from: baseline)

        XCTAssertEqual(streamingAttachments.count, baselineAttachments.count, file: file, line: line)
        XCTAssertEqual(streamingAttachments.map(\.0), baselineAttachments.map(\.0), file: file, line: line)
        XCTAssertEqual(streamingAttachments.map { attachmentKind($0.1.view) }, baselineAttachments.map { attachmentKind($0.1.view) }, file: file, line: line)
        XCTAssertEqual(sut.intrinsicContentSize.height, baseline.intrinsicContentSize.height, accuracy: 5.0, file: file, line: line)
    }

    private func makeComparisonView() -> MarkdownView {
        let view = MarkdownView(theme: makeTestTheme())
        view.frame = CGRect(x: 0, y: 620, width: 342, height: 600)
        view.preferredMaxLayoutWidth = 342
        view.isScrollEnabled = false
        hostWindow.addSubview(view)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        return view
    }

    private func renderNonStreaming(on view: MarkdownView, markdown: String) {
        view.isStreaming = false
        view.markdown = markdown
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        view.layoutIfNeeded()
    }

    private func renderStreamingThenFinalize(on view: MarkdownView, chunks: [String]) {
        view.isStreaming = true
        view.throttleInterval = 0.05
        for chunk in chunks {
            view.markdown = chunk
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            view.layoutIfNeeded()
        }
        view.isStreaming = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        view.layoutIfNeeded()
    }

    private func sortedAttachmentInfos(from view: MarkdownView) -> [(Int, AttachmentInfo)] {
        view.attachmentViews.sorted { $0.key < $1.key }
    }

    private func attachmentKind(_ view: UIView) -> String {
        if view is MarkdownTableView { return "table" }
        if view is CodeBlockView { return "code" }
        if view is QuoteView { return "quote" }
        if view is MarkdownImageView { return "image" }
        if view is HorizontalRuleView { return "hr" }
        return "other"
    }

    private func tableContentKey(from view: MarkdownView) throws -> MarkdownTableContentKey {
        let info = try XCTUnwrap(sortedAttachmentInfos(from: view).map(\.1).first)
        return try XCTUnwrap(info.contentKey.base as? MarkdownTableContentKey)
    }

    private func sizeDiffers(_ lhs: CGSize, _ rhs: CGSize) -> Bool {
        abs(lhs.width - rhs.width) > 0.5 || abs(lhs.height - rhs.height) > 0.5
    }

    private func stabilizeLayout(for view: MarkdownView) {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        view.layoutIfNeeded()
    }
}
