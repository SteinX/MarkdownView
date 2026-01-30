import UIKit

// MARK: - Markdown Image View
public class MarkdownImageView: UIView, Reusable {
    private let imageView = UIImageView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private var url: URL
    private var imageHandler: MarkdownImageHandler
    
    // For "grayed out" effect in quotes
    public var isDimmed: Bool = false {
        didSet {
            updateDimmedState()
        }
    }
    
    public init(url: URL, imageHandler: MarkdownImageHandler, theme: MarkdownTheme, isDimmed: Bool = false) {
        self.url = url
        self.imageHandler = imageHandler
        self.isDimmed = isDimmed
        super.init(frame: .zero)
        
        setupUI(theme: theme)
        loadImage()
        updateDimmedState()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI(theme: MarkdownTheme) {
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 4
        imageView.backgroundColor = theme.images.backgroundColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Default placeholder
        imageView.image = theme.images.loadingPlaceholder
        imageView.tintColor = .systemGray4
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(imageView)
        addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func updateDimmedState() {
        if isDimmed {
            imageView.alpha = 0.7
        } else {
            imageView.alpha = 1.0
        }
    }
    
    private func loadImage() {
        activityIndicator.startAnimating()
        imageHandler.loadImage(url: url, imageView: imageView) { [weak self] image in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()
            
            if let image = image {
                self.imageView.image = image
                self.imageView.contentMode = .scaleAspectFit
            }
        }
    }
    
    // MARK: - Reuse Support
    
    /// Update the view with new content
    public func update(url: URL, imageHandler: MarkdownImageHandler, theme: MarkdownTheme, isDimmed: Bool) {
        // Check if we can skip update
        if self.url == url && self.isDimmed == isDimmed {
            return
        }
        
        // Update state
        self.url = url
        self.imageHandler = imageHandler
        self.isDimmed = isDimmed
        
        // Update UI
        imageView.backgroundColor = theme.images.backgroundColor
        imageView.image = theme.images.loadingPlaceholder
        imageView.tintColor = .systemGray4
        
        updateDimmedState()
        loadImage()
    }
    
    /// Prepare view for reuse
    public func prepareForReuse() {
        imageView.image = nil
        activityIndicator.stopAnimating()
        isDimmed = false
    }
}
