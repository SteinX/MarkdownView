import UIKit

/// Pool for reusing attachment views to reduce allocation overhead during streaming
/// Uses NSCache with strong references for automatic memory pressure handling
public class AttachmentPool {
    public static let shared = AttachmentPool()
    
    private let cache = NSCache<NSString, NSMutableArray>()
    private let maxViewsPerType = 20
    
    private init() {
        cache.countLimit = 100 // Total pool size limit
    }
    
    /// Dequeue a reusable view of the specified type
    /// Returns nil if no views are available in the pool
    public func dequeue<T: UIView>(_ type: T.Type) -> T? {
        let key = String(describing: type) as NSString
        
        guard let array = cache.object(forKey: key),
              array.count > 0,
              let view = array.lastObject as? T else {
            return nil
        }
        
        array.removeLastObject()
        return view
    }
    
    /// Recycle a view back into the pool for future reuse
    /// Calls prepareForReuse() if the view conforms to Reusable protocol
    public func recycle(_ view: UIView) {
        let key = String(describing: type(of: view)) as NSString
        
        // Get or create array for this type
        let array: NSMutableArray
        if let existing = cache.object(forKey: key) {
            array = existing
        } else {
            array = NSMutableArray()
            cache.setObject(array, forKey: key)
        }
        
        // Enforce per-type limit
        guard array.count < maxViewsPerType else { return }
        
        // Prepare for reuse
        if let reusable = view as? Reusable {
            reusable.prepareForReuse()
        }
        
        // Remove from superview before pooling
        view.removeFromSuperview()
        
        array.add(view)
    }
    
    /// Clear all pooled views (useful for memory warnings)
    public func clear() {
        cache.removeAllObjects()
    }
}

/// Protocol for views that support reuse
public protocol Reusable {
    func prepareForReuse()
}
