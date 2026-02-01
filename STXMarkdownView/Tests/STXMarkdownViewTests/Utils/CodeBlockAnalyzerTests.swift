import XCTest
@testable import STXMarkdownView

@MainActor
final class CodeBlockAnalyzerTests: XCTestCase {
    func testAnalyzeEmptyMarkdownReturnsEmptyState() {
        let result = CodeBlockAnalyzer.analyze("")
        XCTAssertFalse(result.hasUnclosedBlock)
        XCTAssertEqual(result.totalCodeBlocks, 0)
        XCTAssertNil(result.unclosedLanguage)
        XCTAssertNil(result.unclosedStartLine)
    }

    func testAnalyzeNoCodeBlocksReturnsZero() {
        let result = CodeBlockAnalyzer.analyze("Hello\nWorld")
        XCTAssertFalse(result.hasUnclosedBlock)
        XCTAssertEqual(result.totalCodeBlocks, 0)
    }

    func testAnalyzeSingleClosedCodeBlock() {
        let markdown = "```swift\nprint(\"hi\")\n```"
        let result = CodeBlockAnalyzer.analyze(markdown)
        XCTAssertFalse(result.hasUnclosedBlock)
        XCTAssertEqual(result.totalCodeBlocks, 1)
        XCTAssertNil(result.unclosedLanguage)
        XCTAssertNil(result.unclosedStartLine)
    }

    func testAnalyzeMultipleClosedCodeBlocks() {
        let markdown = "```swift\nprint(\"one\")\n```\ntext\n```js\nconsole.log(\"two\")\n```"
        let result = CodeBlockAnalyzer.analyze(markdown)
        XCTAssertFalse(result.hasUnclosedBlock)
        XCTAssertEqual(result.totalCodeBlocks, 2)
    }

    func testAnalyzeUnclosedCodeBlock() {
        let markdown = "```swift\nprint(\"oops\")"
        let result = CodeBlockAnalyzer.analyze(markdown)
        XCTAssertTrue(result.hasUnclosedBlock)
        XCTAssertEqual(result.totalCodeBlocks, 1)
        XCTAssertEqual(result.unclosedLanguage, "swift")
        XCTAssertEqual(result.unclosedStartLine, 1)
    }

    func testAnalyzeUnclosedLastBlockWithClosedBefore() {
        let markdown = "```swift\nprint(\"first\")\n```\n```js\nconsole.log(\"second\")"
        let result = CodeBlockAnalyzer.analyze(markdown)
        XCTAssertTrue(result.hasUnclosedBlock)
        XCTAssertEqual(result.totalCodeBlocks, 2)
        XCTAssertEqual(result.unclosedLanguage, "js")
        XCTAssertEqual(result.unclosedStartLine, 4)
    }

    func testAnalyzeFenceTildeWorks() {
        let markdown = "~~~\ncode\n~~~"
        let result = CodeBlockAnalyzer.analyze(markdown)
        XCTAssertFalse(result.hasUnclosedBlock)
        XCTAssertEqual(result.totalCodeBlocks, 1)
    }

    func testAnalyzeMismatchedFenceDoesNotClose() {
        let markdown = "```\ncode\n~~~"
        let result = CodeBlockAnalyzer.analyze(markdown)
        XCTAssertTrue(result.hasUnclosedBlock)
        XCTAssertEqual(result.totalCodeBlocks, 1)
        XCTAssertEqual(result.unclosedStartLine, 1)
    }
}
