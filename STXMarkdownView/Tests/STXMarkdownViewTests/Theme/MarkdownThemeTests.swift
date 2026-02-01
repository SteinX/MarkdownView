import XCTest
@testable import STXMarkdownView

@MainActor
final class MarkdownThemeTests: XCTestCase {
    func testDefaultThemeHasExpectedFonts() {
        let theme = MarkdownTheme.default
        XCTAssertEqual(theme.headings.fonts.count, 6)
        XCTAssertEqual(theme.headings.spacings.count, 6)
    }

    func testLayoutColorsDimmedLowersAlpha() {
        let colors = MarkdownTheme.LayoutColors(text: UIColor.red, secondaryText: UIColor.green, background: UIColor.blue)
        let dimmed = colors.dimmed()
        let baseAlpha = rgbaComponents(colors.text).3
        let dimmedAlpha = rgbaComponents(dimmed.text).3
        XCTAssertLessThan(dimmedAlpha, baseAlpha)
    }

    func testCodeBlockThemeDimmedAdjustsAlpha() {
        let theme = makeTestTheme()
        let dimmed = theme.code.dimmed()
        let baseAlpha = rgbaComponents(theme.code.backgroundColor).3
        let dimmedAlpha = rgbaComponents(dimmed.backgroundColor).3
        XCTAssertLessThan(dimmedAlpha, baseAlpha)
    }

    func testListThemeDimmedAdjustsCheckboxColor() {
        let theme = makeTestTheme()
        let dimmed = theme.lists.dimmed()
        let baseAlpha = rgbaComponents(theme.lists.checkboxColor).3
        let dimmedAlpha = rgbaComponents(dimmed.checkboxColor).3
        XCTAssertLessThan(dimmedAlpha, baseAlpha)
    }

    func testTableThemeDimmedAdjustsBorderColor() {
        let theme = makeTestTheme()
        let dimmed = theme.tables.dimmed()
        let baseAlpha = rgbaComponents(theme.tables.borderColor).3
        let dimmedAlpha = rgbaComponents(dimmed.borderColor).3
        XCTAssertLessThan(dimmedAlpha, baseAlpha)
    }

    func testImageThemeDimmedAdjustsBackgroundColor() {
        let theme = makeTestTheme()
        let imageTheme = MarkdownTheme.ImageTheme(loadingPlaceholder: nil, backgroundColor: .red, inlineSize: theme.images.inlineSize)
        let custom = MarkdownTheme(
            baseFont: theme.baseFont,
            colors: theme.colors,
            headings: theme.headings,
            code: theme.code,
            quote: theme.quote,
            lists: theme.lists,
            tables: theme.tables,
            images: imageTheme,
            paragraphSpacing: theme.paragraphSpacing,
            linkColor: theme.linkColor,
            separatorColor: theme.separatorColor
        )
        let dimmed = custom.images.dimmed()
        let baseAlpha = rgbaComponents(custom.images.backgroundColor).3
        let dimmedAlpha = rgbaComponents(dimmed.backgroundColor).3
        XCTAssertLessThan(dimmedAlpha, baseAlpha)
    }

    func testQuotedThemeOverridesTextColor() {
        let theme = makeTestTheme()
        let quoted = theme.quoted
        XCTAssertNotEqual(rgbaComponents(quoted.colors.text).0, rgbaComponents(theme.colors.text).0)
    }
}
