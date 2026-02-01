import UIKit
@testable import STXMarkdownView

struct TestContentKey: AttachmentContentKey {
    let id: String
}

final class MockImageHandler: MarkdownImageHandler {
    private(set) var loadedURLs: [URL] = []

    func loadImage(url: URL, targetSize: CGSize, imageView: UIImageView, completion: @escaping (UIImage?) -> Void) {
        loadedURLs.append(url)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: max(1, targetSize.width), height: max(1, targetSize.height)))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: renderer.format.bounds.size))
        }
        DispatchQueue.main.async {
            completion(image)
        }
    }
}

func makeTestTheme() -> MarkdownTheme {
    let baseFont = UIFont.systemFont(ofSize: 14)
    let colors = MarkdownTheme.LayoutColors(
        text: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
        secondaryText: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),
        background: UIColor(red: 1, green: 1, blue: 1, alpha: 1)
    )
    let headings = MarkdownTheme.HeadingTheme(
        fonts: [
            .boldSystemFont(ofSize: 22),
            .boldSystemFont(ofSize: 20),
            .boldSystemFont(ofSize: 18),
            .boldSystemFont(ofSize: 16),
            .boldSystemFont(ofSize: 15),
            .boldSystemFont(ofSize: 14)
        ],
        spacings: [16, 12, 10, 8, 8, 8]
    )
    let code = MarkdownTheme.CodeBlockTheme(
        font: .monospacedSystemFont(ofSize: 12, weight: .regular),
        backgroundColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1),
        textColor: UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1),
        headerColor: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1),
        languageLabelFont: .systemFont(ofSize: 11, weight: .medium),
        languageLabelColor: UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1),
        syntaxHighlightTheme: "atom-one-dark",
        isScrollable: false
    )
    let quote = MarkdownTheme.QuoteTheme(
        textColor: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1),
        backgroundColor: UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1),
        borderColor: UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    )
    let lists = MarkdownTheme.ListTheme(
        baseFont: baseFont,
        spacing: 4,
        indentStep: 18,
        markerSpacing: 22,
        bulletMarkers: ["-", "*", "+"],
        checkboxCheckedImage: nil,
        checkboxUncheckedImage: nil,
        checkboxColor: UIColor(red: 0, green: 0.4, blue: 0.8, alpha: 1)
    )
    let tables = MarkdownTheme.TableTheme(
        borderColor: UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1),
        headerColor: UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1),
        minColumnWidth: 40,
        columnDistribution: .automatic
    )
    let images = MarkdownTheme.ImageTheme(
        loadingPlaceholder: nil,
        backgroundColor: UIColor.clear,
        inlineSize: 18
    )

    return MarkdownTheme(
        baseFont: baseFont,
        colors: colors,
        headings: headings,
        code: code,
        quote: quote,
        lists: lists,
        tables: tables,
        images: images,
        paragraphSpacing: 10,
        linkColor: UIColor(red: 0, green: 0.4, blue: 0.9, alpha: 1),
        separatorColor: UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 1)
    )
}

func rgbaComponents(_ color: UIColor) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    if color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
        return (red, green, blue, alpha)
    }
    let ciColor = CIColor(color: color)
    return (ciColor.red, ciColor.green, ciColor.blue, ciColor.alpha)
}

func writeTempImageFile(size: CGSize = CGSize(width: 12, height: 12), color: UIColor = .blue) throws -> URL {
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
    }
    guard let data = image.pngData() else {
        throw NSError(domain: "TestImage", code: 1)
    }
    let fileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("stx-image-\(UUID().uuidString)")
        .appendingPathExtension("png")
    try data.write(to: fileURL)
    return fileURL
}
