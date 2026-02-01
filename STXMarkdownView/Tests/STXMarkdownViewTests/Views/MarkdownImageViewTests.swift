import XCTest
@testable import STXMarkdownView

@MainActor
final class MarkdownImageViewTests: XCTestCase {
    func testUpdateSkipsWhenSameStateWithImage() {
        let handler = MockImageHandler()
        let theme = makeTestTheme()
        let url = URL(string: "https://example.com/image.png")!
        let view = MarkdownImageView(url: url, imageHandler: handler, theme: theme, isDimmed: false)

        let imageView = view.subviews.compactMap { $0 as? UIImageView }.first
        imageView?.image = UIImage()

        let loadCountBefore = handler.loadedURLs.count
        view.update(url: url, imageHandler: handler, theme: theme, isDimmed: false)
        XCTAssertEqual(handler.loadedURLs.count, loadCountBefore)
    }

    func testPrepareForReuseResetsDimmedState() {
        let handler = MockImageHandler()
        let theme = makeTestTheme()
        let url = URL(string: "https://example.com/image.png")!
        let view = MarkdownImageView(url: url, imageHandler: handler, theme: theme, isDimmed: true)
        view.prepareForReuse()
        XCTAssertFalse(view.isDimmed)
    }
}
