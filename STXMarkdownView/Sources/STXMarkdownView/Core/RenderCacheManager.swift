import UIKit
import Markdown

/// Manages render input/output caching for MarkdownView.
/// Caches parsed documents, intrinsic sizes, and rendered strings to avoid redundant work.
final class RenderCacheManager {
    // MARK: - Cached State
    private(set) var document: Document?
    private(set) var intrinsicSize: CGSize?
    private(set) var intrinsicSizeContainerWidth: CGFloat = -1
    private(set) var lastRenderedMarkdown: String?
    private(set) var lastRenderedWidth: CGFloat = 0
    var lastRenderedString: NSAttributedString?
    private(set) var inputVersion: Int = 0
    private(set) var lastRenderedInputVersion: Int = -1
    
    // MARK: - Validation
    
    private static let widthEpsilon: CGFloat = 0.5
    
    /// Check if we can skip render for identical content at same width.
    func shouldSkipRender(markdown: String, width: CGFloat) -> Bool {
        return markdown == lastRenderedMarkdown
            && abs(width - lastRenderedWidth) <= Self.widthEpsilon
            && inputVersion == lastRenderedInputVersion
    }
    
    /// Check if cached intrinsic size is valid for container width.
    func validIntrinsicSize(for containerWidth: CGFloat) -> CGSize? {
        guard let size = intrinsicSize else { return nil }
        guard abs(containerWidth - intrinsicSizeContainerWidth) <= Self.widthEpsilon else { return nil }
        return size
    }
    
    // MARK: - Updates
    
    /// Cache parsed document.
    func cacheDocument(_ document: Document?) {
        self.document = document
    }
    
    /// Cache render results.
    func cacheRenderResult(
        markdown: String,
        width: CGFloat,
        attributedString: NSAttributedString,
        intrinsicSize: CGSize,
        containerWidth: CGFloat
    ) {
        lastRenderedMarkdown = markdown
        lastRenderedWidth = width
        lastRenderedString = attributedString
        lastRenderedInputVersion = inputVersion
        self.intrinsicSize = intrinsicSize
        self.intrinsicSizeContainerWidth = containerWidth
    }
    
    /// Invalidate document cache (e.g., when theme changes).
    func invalidateDocument() {
        document = nil
        inputVersion &+= 1
    }
    
    /// Invalidate intrinsic size cache (e.g., on width change).
    func invalidateIntrinsicSize() {
        intrinsicSize = nil
        intrinsicSizeContainerWidth = -1
    }
    
    /// Increment input version to force re-render.
    func bumpInputVersion() {
        inputVersion &+= 1
    }
    
    /// Reset all cached state.
    func reset() {
        document = nil
        intrinsicSize = nil
        intrinsicSizeContainerWidth = -1
        lastRenderedMarkdown = nil
        lastRenderedWidth = 0
        lastRenderedString = nil
        inputVersion = 0
        lastRenderedInputVersion = -1
    }
}
