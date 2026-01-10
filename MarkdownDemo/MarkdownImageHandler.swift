import UIKit

public protocol MarkdownImageHandler {
    func loadImage(url: URL, imageView: UIImageView, completion: @escaping (UIImage?) -> Void)
}

public class DefaultImageHandler: MarkdownImageHandler {
    public init() {}
    
    public func loadImage(url: URL, imageView: UIImageView, completion: @escaping (UIImage?) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    completion(image)
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}
