import XCTest
import UIKit
@testable import STXMarkdownView

final class AttachmentPoolTests: XCTestCase {
    private struct DummyKey: AttachmentContentKey { let id: Int }
    private final class ReusableView: UIView, Reusable {
        var didPrepare = false
        func prepareForReuse() { didPrepare = true }
    }

    @MainActor
    func testDequeueEmptyReturnsNil() {
        let pool = AttachmentPool()
        let result: (view: UIView, exactMatch: Bool)? = pool.dequeue(for: DummyKey(id: 1), isStreaming: false)
        XCTAssertNil(result)
    }

    @MainActor
    func testRecycleThenDequeueReturnsView() {
        let pool = AttachmentPool()
        let view = UIView()
        let key = DummyKey(id: 1)
        pool.recycle(view, key: key, isStreaming: false)
        let result: (view: UIView, exactMatch: Bool)? = pool.dequeue(for: key, isStreaming: false)
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.exactMatch ?? false)
        XCTAssertTrue(result?.view === view)
    }

    @MainActor
    func testRecycleStreamingUsesStreamingPool() {
        let pool = AttachmentPool()
        let view = UIView()
        pool.recycle(view, anyKey: AnyHashable(DummyKey(id: 1)), isStreaming: true)
        let result: (view: UIView, exactMatch: Bool)? = pool.dequeue(for: DummyKey(id: 2), isStreaming: true)
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.exactMatch ?? true)
        XCTAssertTrue(result?.view === view)
    }

    @MainActor
    func testClearRemovesAll() {
        let pool = AttachmentPool()
        let view = UIView()
        let key = DummyKey(id: 1)
        pool.recycle(view, key: key, isStreaming: false)
        pool.clear()
        let result: (view: UIView, exactMatch: Bool)? = pool.dequeue(for: key, isStreaming: false)
        XCTAssertNil(result)
    }

    func testRecycleCallsPrepareForReuseInStreaming() async {
        let didPrepare = await MainActor.run { () -> Bool in
            let pool = AttachmentPool()
            let view = ReusableView()
            pool.recycle(view, anyKey: AnyHashable(DummyKey(id: 1)), isStreaming: true)
            return view.didPrepare
        }
        XCTAssertTrue(didPrepare)
    }
}
