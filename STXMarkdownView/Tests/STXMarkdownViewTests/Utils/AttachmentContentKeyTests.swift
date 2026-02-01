import XCTest
@testable import STXMarkdownView

@MainActor
final class AttachmentContentKeyTests: XCTestCase {
    func testAnyKeyWrapsContentKey() {
        let key = TestContentKey(id: "one")
        let anyKey = key.anyKey
        XCTAssertEqual(anyKey.hashValue, TestContentKey(id: "one").hashValue)
    }

    func testAttachmentInfoStoresValues() {
        let view = UIView()
        let key = TestContentKey(id: "two")
        let info = AttachmentInfo(view: view, contentKey: key.anyKey, charPosition: 12)
        XCTAssertTrue(info.view === view)
        XCTAssertEqual(info.contentKey.hashValue, key.hashValue)
        XCTAssertEqual(info.charPosition, 12)
    }
}
