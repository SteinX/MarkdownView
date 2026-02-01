import UIKit

/// Pool for reusing attachment views to reduce allocation overhead during streaming.
/// Uses a content-keyed dictionary with time-based expiry and LRU eviction.
public class AttachmentPool {
    private var contentPool: [AnyHashable: [(view: UIView, timestamp: Date)]] = [:]
    private var accessOrder: [AnyHashable] = []
    private var streamingPool: [String: UIView] = [:]
    private let expirationInterval: TimeInterval = 30
    private let maxPoolSize: Int
    private let lock = NSLock()

    private var hitCount = 0
    private var missCount = 0
    private var recycleCount = 0
    private var streamingHitCount = 0
    private var streamingRecycleCount = 0
    private var expiredEvictionCount = 0
    private var lruEvictionCount = 0

    public init() {
        let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)

        switch memoryGB {
        case ..<4.0:
            maxPoolSize = 50
        case 4.0..<8.0:
            maxPoolSize = 100
        default:
            maxPoolSize = 200
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )

        MarkdownLogger.info(.pool, "Initialized pool with memory=\(String(format: "%.1f", memoryGB))GB, maxSize=\(maxPoolSize), expiration=\(Int(expirationInterval))s")
    }

    /// Dequeue a reusable view for the given content key.
    /// Returns nil if no views are available for the key.
    /// If the view comes from the streaming pool, exactMatch will be false.
    public func dequeue<T: UIView, K: AttachmentContentKey>(for key: K, isStreaming: Bool) -> (view: T, exactMatch: Bool)? {
        lock.lock()
        defer { lock.unlock() }

        let anyKey = AnyHashable(key)
        MarkdownLogger.verbose(.pool, "dequeue request key=\(String(describing: K.self)) hash=\(anyKey.hashValue) keys=\(contentPool.count) streaming=\(streamingPool.count) isStreaming=\(isStreaming)")

        if var cachedArray = contentPool[anyKey] {
            while !cachedArray.isEmpty {
                let cached = cachedArray.removeLast()
                if let view = cached.view as? T {
                    hitCount += 1
                    if cachedArray.isEmpty {
                        contentPool.removeValue(forKey: anyKey)
                        removeFromAccessOrder(anyKey)
                    } else {
                        contentPool[anyKey] = cachedArray
                    }
                    MarkdownLogger.verbose(.pool, "dequeue \(K.self) hit, remainingKeys=\(contentPool.count), hit=\(hitCount)")
                    return (view, true)
                }
            }
            contentPool.removeValue(forKey: anyKey)
            removeFromAccessOrder(anyKey)
        }

        missCount += 1
        MarkdownLogger.verbose(.pool, "dequeue \(K.self) miss, keys=\(contentPool.count), streaming=\(streamingPool.count), miss=\(missCount)")

        let typeName = String(describing: T.self)
        if let streamingView = streamingPool.removeValue(forKey: typeName) as? T {
            streamingHitCount += 1
            MarkdownLogger.verbose(.pool, "dequeue \(K.self) streaming fallback type=\(typeName), streaming=\(streamingPool.count), streamingHit=\(streamingHitCount)")
            return (streamingView, false)
        }

        return nil
    }

    /// Recycle a view back into the pool for future reuse.
    /// Calls prepareForReuse() if the view conforms to Reusable protocol.
    public func recycle<K: AttachmentContentKey>(_ view: UIView, key: K, isStreaming: Bool) {
        recycle(view, anyKey: AnyHashable(key), isStreaming: isStreaming)
    }

    /// Recycle using an already-typed AnyHashable key.
    public func recycle(_ view: UIView, anyKey: AnyHashable, isStreaming: Bool) {
        lock.lock()
        defer { lock.unlock() }

        view.removeFromSuperview()

        recycleCount += 1
        if isStreaming {
            if let reusable = view as? Reusable {
                reusable.prepareForReuse()
            }
            let typeName = String(describing: type(of: view))
            streamingPool[typeName] = view
            streamingRecycleCount += 1
            MarkdownLogger.verbose(.pool, "recycle streaming type=\(typeName), streaming=\(streamingPool.count), streamingRecycle=\(streamingRecycleCount)")
        } else {
            contentPool[anyKey, default: []].append((view, Date()))
            updateAccessOrder(anyKey)
            evictIfNeeded()
            MarkdownLogger.verbose(.pool, "recycle content hash=\(anyKey.hashValue), keys=\(contentPool.count), recycle=\(recycleCount)")
        }
    }

    /// Clear all pooled views (useful for memory warnings).
    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        contentPool.removeAll()
        accessOrder.removeAll()
        streamingPool.removeAll()
        hitCount = 0
        missCount = 0
        recycleCount = 0
        streamingHitCount = 0
        streamingRecycleCount = 0
        expiredEvictionCount = 0
        lruEvictionCount = 0
        MarkdownLogger.info(.pool, "clear all pooled views")
    }

    public func logStats(context: String) {
        lock.lock()
        defer { lock.unlock() }

        let totalViews = contentPool.values.reduce(0) { $0 + $1.count }

        MarkdownLogger.debug(
            .pool,
            "stats \(context) keys=\(contentPool.count), views=\(totalViews), streaming=\(streamingPool.count), hit=\(hitCount), miss=\(missCount), streamingHit=\(streamingHitCount), recycle=\(recycleCount), streamingRecycle=\(streamingRecycleCount), expired=\(expiredEvictionCount), lru=\(lruEvictionCount)"
        )
    }

    private func updateAccessOrder(_ key: AnyHashable) {
        removeFromAccessOrder(key)
        accessOrder.append(key)
    }

    private func removeFromAccessOrder(_ key: AnyHashable) {
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
    }

    private func evictIfNeeded() {
        let now = Date()

        var expiredRemoved = 0
        for (key, values) in contentPool {
            let filtered = values.filter {
                now.timeIntervalSince($0.timestamp) <= expirationInterval
            }
            if filtered.count != values.count {
                expiredRemoved += values.count - filtered.count
            }
            if filtered.isEmpty {
                contentPool.removeValue(forKey: key)
                removeFromAccessOrder(key)
            } else if filtered.count != values.count {
                contentPool[key] = filtered
            }
        }
        if expiredRemoved > 0 {
            expiredEvictionCount += expiredRemoved
        }

        var totalViews = contentPool.values.reduce(0) { $0 + $1.count }
        while totalViews > maxPoolSize, let oldest = accessOrder.first {
            if let removed = contentPool.removeValue(forKey: oldest) {
                totalViews -= removed.count
                lruEvictionCount += removed.count
            }
            accessOrder.removeFirst()
        }

        if expiredRemoved > 0 || lruEvictionCount > 0 {
            MarkdownLogger.debug(.pool, "evict expired=\(expiredRemoved), lruTotal=\(lruEvictionCount), keys=\(contentPool.count), views=\(totalViews)")
        }
    }

    @objc private func handleMemoryWarning() {
        lock.lock()
        defer { lock.unlock() }

        let evictCount = accessOrder.count / 2
        for key in accessOrder.prefix(evictCount) {
            contentPool.removeValue(forKey: key)
        }
        accessOrder.removeFirst(min(evictCount, accessOrder.count))
        streamingPool.removeAll()
        streamingHitCount = 0
        streamingRecycleCount = 0

        MarkdownLogger.warning(.pool, "memory warning: evicted \(evictCount), remaining=\(contentPool.count)")
    }
}

/// Protocol for views that support reuse
public protocol Reusable {
    func prepareForReuse()
}
