import UIKit
import Markdown

/// Result of the markdown rendering including the text and view attachments.
public struct RenderedMarkdown {
    public let attributedString: NSAttributedString
    public let attachments: [Int: AttachmentInfo]
}

/// A public renderer that converts Markdown text into NSAttributedString.
/// This is the main entry point for the Markdown library.
public class MarkdownRenderer {
    
    public let theme: MarkdownTheme
    public let imageHandler: MarkdownImageHandler
    public let maxLayoutWidth: CGFloat
    
    /// Initializes the renderer with configuration options.
    /// - Parameters:
    ///   - theme: The theme to use for styling. Defaults to `MarkdownTheme.default`.
    ///   - imageHandler: Handler for loading images. Defaults to `DefaultImageHandler`.
    ///   - maxLayoutWidth: The maximum width for layout calculations (important for tables, blocks, etc.).
    public init(theme: MarkdownTheme = .default, imageHandler: MarkdownImageHandler = DefaultImageHandler(), maxLayoutWidth: CGFloat = 0) {
        self.theme = theme
        self.imageHandler = imageHandler
        
        if maxLayoutWidth > 0 {
            self.maxLayoutWidth = maxLayoutWidth
        } else {
            // Attempt to get screen width from active scene
            let screenWidth: CGFloat
            if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                screenWidth = windowScene.screen.bounds.width
            } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                screenWidth = windowScene.screen.bounds.width
            } else {
                screenWidth = UIScreen.main.bounds.width
            }
            self.maxLayoutWidth = screenWidth
        }
    }
    
    /// Parses the markdown string into a Document AST.
    /// - Parameter markdown: The markdown string.
    /// - Returns: A Swift-Markdown Document.
    public func parse(_ markdown: String) -> Document {
        return Document(parsing: markdown)
    }
    
    /// Renders a pre-parsed Document.
    /// - Parameters:
    ///   - document: The Document AST.
    ///   - attachmentPool: Optional pool for reusing attachment views
    ///   - codeBlockState: Optional state for smart code block highlighting
    ///   - isStreaming: Whether this render is part of a streaming sequence.
    /// - Returns: Rendered result.
    public func render(_ document: Document, attachmentPool: AttachmentPool? = nil, codeBlockState: CodeBlockAnalyzer.CodeBlockState? = nil, isStreaming: Bool = false) -> RenderedMarkdown {
        var parser = MarkdownParser(
            theme: theme,
            maxLayoutWidth: maxLayoutWidth,
            imageHandler: imageHandler,
            attachmentPool: attachmentPool,
            codeBlockState: codeBlockState,
            isStreaming: isStreaming
        )
        
        let item = MarkdownLogger.measure(.renderer, "render document") {
            parser.parse(document)
        }
        
        return RenderedMarkdown(attributedString: item.attributedString, attachments: item.attachments)
    }

    /// Renders the given markdown string into a RenderedMarkdown result.
    /// - Parameter markdown: The markdown string to render.
    /// - Returns: A RenderedMarkdown object containing the styled text and view attachments.
    public func render(_ markdown: String) -> RenderedMarkdown {
        let document = parse(markdown)
        return render(document)
    }
    
    /// Convenience method to calculate the height of the rendered content.
    /// - Parameters:
    ///   - markdown: The markdown content.
    ///   - width: The width constraint.
    /// - Returns: Estimated height.
    public func calculateHeight(for markdown: String, width: CGFloat) -> CGFloat {
        // This is a naive height calculation that doesn't cache.
        // For better performance, we should probably expose a height calculation that takes a Document.
        let result = render(markdown)
        // Use a dummy text view or bounding rect calculation
        let framesetter = CTFramesetterCreateWithAttributedString(result.attributedString)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            nil
        )
        return ceil(suggestedSize.height)
    }
}
