import XCTest
@testable import STXMarkdownView

@MainActor
final class StreamingRenderTests: XCTestCase {
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

    func testStreamingModeToggle() {
        XCTAssertFalse(sut.isStreaming)
        sut.isStreaming = true
        XCTAssertTrue(sut.isStreaming)
        sut.isStreaming = false
        XCTAssertFalse(sut.isStreaming)
    }

    func testStreamingThrottling() {
        sut.isStreaming = true
        sut.throttleInterval = 0.2
        sut.markdown = "A"
        sut.markdown = "AB"
        sut.markdown = "ABC"
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        let interimText = sut.attributedText?.string
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        XCTAssertNotEqual(interimText, sut.attributedText?.string)
    }

    func testStreamingFinalRenderOnDisable() {
        sut.isStreaming = true
        sut.throttleInterval = 0.5
        sut.markdown = "Hello"
        sut.isStreaming = false
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(sut.attributedText?.string.hasPrefix("Hello") ?? false)
    }

    func testAttachmentViewRecycling() {
        sut.isStreaming = true
        sut.throttleInterval = 0.05
        sut.markdown = """
        ```swift
        print("A")
        ```
        """
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        sut.layoutIfNeeded()
        let firstAttachmentCount = sut.attachmentViews.count
        XCTAssertGreaterThan(firstAttachmentCount, 0, "First render should create attachments")
        sut.markdown = """
        ```swift
        print("B")
        ```
        """
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        sut.layoutIfNeeded()
        XCTAssertEqual(firstAttachmentCount, sut.attachmentViews.count)
    }

    func testIncrementalCodeBlockRender() {
        sut.isStreaming = true
        sut.markdown = "```swift\nprint(1)"
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        let midAttachments = sut.attachmentViews.count
        sut.markdown = "```swift\nprint(1)\n```"
        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        XCTAssertGreaterThanOrEqual(sut.attachmentViews.count, midAttachments)
    }

    func testCleanUpClearsState() {
        sut.isStreaming = true
        sut.markdown = "Hello"
        sut.layoutIfNeeded()
        sut.cleanUp()
        XCTAssertEqual(sut.markdown, "")
        XCTAssertTrue(sut.attributedText == nil || sut.attributedText?.length == 0)
    }
}
