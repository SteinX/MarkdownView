import XCTest
@testable import STXMarkdownView

@MainActor
final class MarkdownLoggerTests: XCTestCase {
    func testLoggingDoesNotCrashWhenOff() {
        MarkdownLogger.level = .off
        MarkdownLogger.debug(.renderer, "ignored")
        MarkdownLogger.info(.renderer, "ignored")
        MarkdownLogger.warning(.renderer, "ignored")
        MarkdownLogger.error(.renderer, "ignored")
    }

    func testMeasureReturnsValue() {
        MarkdownLogger.level = .debug
        let value: Int = MarkdownLogger.measure(.renderer, "test") {
            return 42
        }
        XCTAssertEqual(value, 42)
        MarkdownLogger.level = .off
    }
}
