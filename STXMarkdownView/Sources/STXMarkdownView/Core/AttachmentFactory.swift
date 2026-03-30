import UIKit

struct AttachmentFactory {
    let theme: MarkdownTheme
    let imageHandler: MarkdownImageHandler
    let isInsideQuote: Bool
    let attachmentPool: AttachmentPool?
    let isStreaming: Bool
    let tableSizeCache: TableCellSizeCache?

    func makeHorizontalRule(
        width: CGFloat
    ) -> (view: HorizontalRuleView, contentKey: HorizontalRuleContentKey, size: CGSize) {
        let contentKey = HorizontalRuleContentKey(
            width: width,
            isInsideQuote: isInsideQuote
        )

        let view: HorizontalRuleView
        if let pool = attachmentPool,
           let (pooledView, exactMatch): (HorizontalRuleView, Bool) = pool.dequeue(
               for: contentKey,
               isStreaming: isStreaming
           ) {
            view = pooledView
            if !exactMatch {
                view.update(theme: theme, width: width)
            }
        } else {
            view = HorizontalRuleView(theme: theme, width: width)
        }

        return (view, contentKey, view.frame.size)
    }

    func makeInlineImage(
        url: URL
    ) -> (view: MarkdownImageView, contentKey: MarkdownImageContentKey, size: CGSize) {
        let side = theme.images.inlineSize
        return makeImage(url: url, size: CGSize(width: side, height: side))
    }

    func makeBlockImage(
        url: URL,
        width: CGFloat
    ) -> (view: MarkdownImageView, contentKey: MarkdownImageContentKey, size: CGSize) {
        let height = width * 0.5625
        return makeImage(url: url, size: CGSize(width: width, height: height))
    }

    func makeImage(
        url: URL,
        size: CGSize
    ) -> (view: MarkdownImageView, contentKey: MarkdownImageContentKey, size: CGSize) {
        let contentKey = MarkdownImageContentKey(
            url: url,
            isDimmed: isInsideQuote,
            width: size.width,
            height: size.height
        )

        let view: MarkdownImageView
        if let pool = attachmentPool,
           let (pooledView, exactMatch): (MarkdownImageView, Bool) = pool.dequeue(
               for: contentKey,
               isStreaming: isStreaming
           ) {
            view = pooledView
            if !exactMatch {
                view.update(
                    url: url,
                    imageHandler: imageHandler,
                    theme: theme,
                    isDimmed: isInsideQuote
                )
            }
        } else {
            view = MarkdownImageView(
                url: url,
                imageHandler: imageHandler,
                theme: theme,
                isDimmed: isInsideQuote
            )
        }

        view.frame = CGRect(origin: .zero, size: size)
        return (view, contentKey, size)
    }

    func makeCodeBlock(
        code: String,
        language: String?,
        width: CGFloat,
        shouldHighlight: Bool
    ) -> (view: CodeBlockView, contentKey: CodeBlockContentKey, size: CGSize) {
        let contentKey = CodeBlockContentKey(
            codeHash: code.hashValue,
            codeLength: code.count,
            language: language,
            shouldHighlight: shouldHighlight,
            width: width,
            isInsideQuote: isInsideQuote
        )

        let view: CodeBlockView
        var isExactMatch = false

        if let pool = attachmentPool,
           let (pooledView, exactMatch): (CodeBlockView, Bool) = pool.dequeue(
               for: contentKey,
               isStreaming: isStreaming
           ) {
            view = pooledView
            isExactMatch = exactMatch
            if !exactMatch {
                view.update(
                    code: code,
                    language: language,
                    theme: theme,
                    shouldHighlight: shouldHighlight
                )
            }
        } else {
            view = CodeBlockView(code: code, language: language, theme: theme)
            if !shouldHighlight {
                view.update(
                    code: code,
                    language: language,
                    theme: theme,
                    shouldHighlight: false
                )
            }
        }

        let size: CGSize
        if isExactMatch, view.frame.size.height > 0 {
            size = CGSize(width: width, height: view.frame.size.height)
        } else {
            view.translatesAutoresizingMaskIntoConstraints = false
            let measuredSize = view.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingExpandedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            size = CGSize(width: width, height: measuredSize.height)
            view.translatesAutoresizingMaskIntoConstraints = true
        }

        view.frame = CGRect(origin: .zero, size: size)
        return (view, contentKey, size)
    }

    func makeQuote(
        sourceHash: Int,
        attributedText: NSAttributedString,
        attachments: [Int: AttachmentInfo],
        width: CGFloat
    ) -> (view: QuoteView, contentKey: QuoteContentKey, size: CGSize) {
        let contentKey = QuoteContentKey(
            sourceHash: sourceHash,
            width: width,
            isInsideQuote: isInsideQuote
        )

        let view: QuoteView
        var isExactMatch = false

        if let pool = attachmentPool,
           let (pooledView, exactMatch): (QuoteView, Bool) = pool.dequeue(
               for: contentKey,
               isStreaming: isStreaming
           ) {
            view = pooledView
            isExactMatch = exactMatch
            if !exactMatch {
                view.update(
                    attributedText: attributedText,
                    attachments: attachments,
                    theme: theme
                )
            }
        } else {
            view = QuoteView(
                attributedText: attributedText,
                attachments: attachments,
                theme: theme
            )
        }

        view.translatesAutoresizingMaskIntoConstraints = false
        view.preferredMaxLayoutWidth = width

        let size: CGSize
        if isExactMatch, view.frame.size.height > 0 {
            size = CGSize(width: width, height: view.frame.size.height)
        } else {
            view.frame = CGRect(x: 0, y: 0, width: width, height: 1000)
            let measuredSize = view.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingExpandedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            )
            size = CGSize(width: width, height: measuredSize.height)
        }

        view.frame = CGRect(origin: .zero, size: size)
        view.preferredMaxLayoutWidth = nil
        view.translatesAutoresizingMaskIntoConstraints = true

        return (view, contentKey, size)
    }

    func makeTable(
        headers: [(NSAttributedString, [Int: AttachmentInfo])],
        rows: [[(NSAttributedString, [Int: AttachmentInfo])]],
        dataHash: Int,
        width: CGFloat,
        precomputedLayout: MarkdownTableLayoutResult? = nil
    ) -> (view: MarkdownTableView, contentKey: MarkdownTableContentKey, size: CGSize) {
        let contentKey = MarkdownTableContentKey(
            dataHash: dataHash,
            width: width,
            isInsideQuote: isInsideQuote
        )

        let layoutResult: MarkdownTableLayoutResult
        if let precomputedLayout {
            layoutResult = precomputedLayout
        } else if let cachedLayout = tableSizeCache?.cachedLayout(dataHash: dataHash, width: width) {
            layoutResult = cachedLayout
        } else {
            let headerTexts = headers.map { $0.0 }
            let rowTexts = rows.map { row in row.map { $0.0 } }
            layoutResult = MarkdownTableView.computeLayout(
                headers: headerTexts,
                rows: rowTexts,
                theme: theme,
                maxWidth: width,
                cache: tableSizeCache
            )
            tableSizeCache?.storeLayout(layoutResult, dataHash: dataHash, width: width)
        }

        let view: MarkdownTableView
        if let pool = attachmentPool,
           let (pooledView, exactMatch): (MarkdownTableView, Bool) = pool.dequeue(
               for: contentKey,
               isStreaming: isStreaming
           ) {
            view = pooledView
            if !exactMatch {
                view.update(
                    headers: headers,
                    rows: rows,
                    theme: theme,
                    maxLayoutWidth: width,
                    precomputedLayout: layoutResult,
                    sizeCache: tableSizeCache
                )
            }
        } else {
            view = MarkdownTableView(
                headers: headers,
                rows: rows,
                theme: theme,
                maxLayoutWidth: width,
                precomputedLayout: layoutResult,
                sizeCache: tableSizeCache
            )
        }

        view.frame = CGRect(origin: .zero, size: layoutResult.contentSize)
        return (view, contentKey, layoutResult.contentSize)
    }
}
