import XCTest
import UIKit
@testable import STXMarkdownView

@MainActor
final class ImageCacheTests: XCTestCase {
    func testClearAllResetsDiskCacheSize() {
        let cache = ImageCache(config: ImageCacheConfig(memoryCacheSizeMB: 1, diskCacheSizeMB: 1, diskCacheDirectory: "STXMarkdownViewTests"))
        cache.clearAll()
        XCTAssertEqual(cache.currentDiskCacheSize, 0)
    }

    func testImageFetchFromLocalFileReturnsImage() async throws {
        let cache = ImageCache(config: ImageCacheConfig(memoryCacheSizeMB: 1, diskCacheSizeMB: 1, diskCacheDirectory: "STXMarkdownViewTests"))
        let fileURL = try writeTempImageFile()
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let expectation = expectation(description: "image completion")
        cache.image(for: fileURL, targetSize: CGSize(width: 10, height: 10)) { image in
            XCTAssertNotNil(image)
            expectation.fulfill()
        }
        await fulfillment(of: [expectation], timeout: 5)
    }
}
