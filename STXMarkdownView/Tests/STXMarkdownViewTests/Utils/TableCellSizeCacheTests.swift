import XCTest
@testable import STXMarkdownView

@MainActor
final class TableCellSizeCacheTests: XCTestCase {
    func testIntrinsicWidthCacheStoreAndFetch() {
        let cache = TableCellSizeCache(maxEntries: 10)
        let text = NSAttributedString(string: "Hello")
        XCTAssertNil(cache.intrinsicWidth(for: text))
        cache.storeIntrinsic(text: text, width: 42, height: 10)
        XCTAssertEqual(cache.intrinsicWidth(for: text), 42)
    }

    func testHeightCacheStoreAndFetch() {
        let cache = TableCellSizeCache(maxEntries: 10)
        let text = NSAttributedString(string: "Hello")
        XCTAssertNil(cache.height(for: text, width: 100))
        cache.storeHeight(text: text, width: 100, height: 20)
        XCTAssertEqual(cache.height(for: text, width: 100), 20)
    }

    func testHeightCacheDifferentWidthsAreDistinct() {
        let cache = TableCellSizeCache(maxEntries: 10)
        let text = NSAttributedString(string: "Hello")
        cache.storeHeight(text: text, width: 80, height: 10)
        cache.storeHeight(text: text, width: 120, height: 20)
        XCTAssertEqual(cache.height(for: text, width: 80), 10)
        XCTAssertEqual(cache.height(for: text, width: 120), 20)
    }

    func testCacheEvictsOldestEntry() {
        let cache = TableCellSizeCache(maxEntries: 2)
        let text1 = NSAttributedString(string: "One")
        let text2 = NSAttributedString(string: "Two")
        let text3 = NSAttributedString(string: "Three")

        cache.storeIntrinsic(text: text1, width: 10, height: 10)
        cache.storeIntrinsic(text: text2, width: 20, height: 10)
        _ = cache.intrinsicWidth(for: text1)
        cache.storeIntrinsic(text: text3, width: 30, height: 10)

        XCTAssertNil(cache.intrinsicWidth(for: text2))
        XCTAssertEqual(cache.intrinsicWidth(for: text1), 10)
        XCTAssertEqual(cache.intrinsicWidth(for: text3), 30)
    }
}
