import UIKit

protocol MarkdownImageHandler {
    func loadImage(url: URL, imageView: UIImageView, completion: @escaping (UIImage?) -> Void)
}

class DefaultImageHandler: MarkdownImageHandler {
    func loadImage(url: URL, imageView: UIImageView, completion: @escaping (UIImage?) -> Void) {
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
