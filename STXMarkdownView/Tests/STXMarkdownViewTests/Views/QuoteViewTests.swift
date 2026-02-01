import XCTest
@testable import STXMarkdownView

@MainActor
final class QuoteViewTests: XCTestCase {
    func testUpdateAppliesThemeChanges() {
        let theme = makeTestTheme()
        let text = NSAttributedString(string: "Quote")
        let view = QuoteView(attributedText: text, attachments: [:], theme: theme)

        var updatedTheme = theme
        let newQuote = MarkdownTheme.QuoteTheme(
            textColor: .black,
            backgroundColor: .yellow,
            borderColor: .red,
            borderWidth: 2,
            padding: 6
        )
        updatedTheme = MarkdownTheme(
            baseFont: theme.baseFont,
            colors: theme.colors,
            headings: theme.headings,
            code: theme.code,
            quote: newQuote,
            lists: theme.lists,
            tables: theme.tables,
            images: theme.images,
            paragraphSpacing: theme.paragraphSpacing,
            linkColor: theme.linkColor,
            separatorColor: theme.separatorColor
        )

        view.update(attributedText: text, attachments: [:], theme: updatedTheme)
        XCTAssertEqual(view.backgroundColor, .yellow)
    }

    func testPrepareForReuseAllowsReapplyPreferredWidth() {
        let theme = makeTestTheme()
        let text = NSAttributedString(string: "Quote")
        let view = QuoteView(attributedText: text, attachments: [:], theme: theme)
        view.preferredMaxLayoutWidth = 200
        view.prepareForReuse()
        view.preferredMaxLayoutWidth = 180
        XCTAssertEqual(view.preferredMaxLayoutWidth, 180)
    }
}
