import UIKit

public protocol MarkdownImageHandler {
    func loadImage(url: URL, targetSize: CGSize, imageView: UIImageView, completion: @escaping (UIImage?) -> Void)
}

public class DefaultImageHandler: MarkdownImageHandler {
    public init() {}
    
    public func loadImage(url: URL, targetSize: CGSize, imageView: UIImageView, completion: @escaping (UIImage?) -> Void) {
        ImageCache.shared.image(for: url, targetSize: targetSize, completion: completion)
    }
}
