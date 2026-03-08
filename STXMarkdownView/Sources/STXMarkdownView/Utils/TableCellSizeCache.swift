import UIKit

public final class TableCellSizeCache {
    private struct IntrinsicKey: Hashable {
        let contentHash: Int
    }

    private struct HeightKey: Hashable {
        let contentHash: Int
        let width: Int
    }

    private struct IntrinsicEntry {
        var width: CGFloat
        var height: CGFloat
        var lastAccess: UInt64
    }

    private struct HeightEntry {
        var height: CGFloat
        var lastAccess: UInt64
    }

    private struct LayoutKey: Hashable {
        let dataHash: Int
        let width: Int
    }

    private struct LayoutEntry {
        var result: MarkdownTableLayoutResult
        var lastAccess: UInt64
    }

    private struct AccessRecord {
        let isIntrinsic: Bool
        let access: UInt64
        let intrinsicKey: IntrinsicKey?
        let heightKey: HeightKey?
    }

    private final class CellParseCacheKey: NSObject {
        let contentHash: Int
        let isHeader: Bool

        init(contentHash: Int, isHeader: Bool) {
            self.contentHash = contentHash
            self.isHeader = isHeader
        }

        override var hash: Int {
            var hasher = Hasher()
            hasher.combine(contentHash)
            hasher.combine(isHeader)
            return hasher.finalize()
        }

        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? CellParseCacheKey else { return false }
            return contentHash == other.contentHash && isHeader == other.isHeader
        }
    }

    private let lock = NSLock()
    private var intrinsicCache: [IntrinsicKey: IntrinsicEntry] = [:]
    private var heightCache: [HeightKey: HeightEntry] = [:]
    private var layoutCache: [LayoutKey: LayoutEntry] = [:]
    private let cellParseCache = NSCache<CellParseCacheKey, NSAttributedString>()
    private var accessCounter: UInt64 = 0
    private let maxEntries: Int
    private let maxLayoutEntries: Int = 32
    private var hitsIntrinsic: UInt64 = 0
    private var hitsHeight: UInt64 = 0
    private var hitsLayout: UInt64 = 0
    private var hitsCellParse: UInt64 = 0
    private var missesIntrinsic: UInt64 = 0
    private var missesHeight: UInt64 = 0
    private var missesLayout: UInt64 = 0
    private var missesCellParse: UInt64 = 0
    private var evictions: UInt64 = 0

    public init(maxEntries: Int = 800) {
        self.maxEntries = maxEntries
        cellParseCache.countLimit = 200
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func intrinsicWidth(for text: NSAttributedString) -> CGFloat? {
        let key = IntrinsicKey(contentHash: text.hash)
        lock.lock()
        defer { lock.unlock() }

        guard var entry = intrinsicCache[key] else { return nil }
        accessCounter += 1
        entry.lastAccess = accessCounter
        intrinsicCache[key] = entry
        hitsIntrinsic += 1
        return entry.width
    }

    func height(for text: NSAttributedString, width: CGFloat) -> CGFloat? {
        let widthKey = Int(round(max(0, width)))
        let key = HeightKey(contentHash: text.hash, width: widthKey)
        lock.lock()
        defer { lock.unlock() }

        guard var entry = heightCache[key] else { return nil }
        accessCounter += 1
        entry.lastAccess = accessCounter
        heightCache[key] = entry
        hitsHeight += 1
        return entry.height
    }

    func storeIntrinsic(text: NSAttributedString, width: CGFloat, height: CGFloat) {
        let key = IntrinsicKey(contentHash: text.hash)
        lock.lock()
        accessCounter += 1
        intrinsicCache[key] = IntrinsicEntry(width: width, height: height, lastAccess: accessCounter)
        missesIntrinsic += 1
        evictIfNeeded()
        lock.unlock()
    }

    func storeHeight(text: NSAttributedString, width: CGFloat, height: CGFloat) {
        let widthKey = Int(round(max(0, width)))
        let key = HeightKey(contentHash: text.hash, width: widthKey)
        lock.lock()
        accessCounter += 1
        heightCache[key] = HeightEntry(height: height, lastAccess: accessCounter)
        missesHeight += 1
        evictIfNeeded()
        lock.unlock()
    }

    func cachedLayout(dataHash: Int, width: CGFloat) -> MarkdownTableLayoutResult? {
        let key = LayoutKey(dataHash: dataHash, width: Int(round(max(0, width))))
        lock.lock()
        defer { lock.unlock() }

        guard var entry = layoutCache[key] else {
            missesLayout += 1
            return nil
        }
        accessCounter += 1
        entry.lastAccess = accessCounter
        layoutCache[key] = entry
        hitsLayout += 1
        return entry.result
    }

    func storeLayout(_ result: MarkdownTableLayoutResult, dataHash: Int, width: CGFloat) {
        let key = LayoutKey(dataHash: dataHash, width: Int(round(max(0, width))))
        lock.lock()
        accessCounter += 1
        layoutCache[key] = LayoutEntry(result: result, lastAccess: accessCounter)
        if layoutCache.count > maxLayoutEntries {
            let sorted = layoutCache.sorted { $0.value.lastAccess < $1.value.lastAccess }
            let removeCount = layoutCache.count - maxLayoutEntries + maxLayoutEntries / 4
            for i in 0..<min(removeCount, sorted.count) {
                layoutCache.removeValue(forKey: sorted[i].key)
            }
        }
        lock.unlock()
    }

    func cachedCellParse(contentHash: Int, isHeader: Bool) -> NSAttributedString? {
        let key = CellParseCacheKey(contentHash: contentHash, isHeader: isHeader)
        if let cached = cellParseCache.object(forKey: key) {
            lock.lock()
            hitsCellParse += 1
            lock.unlock()
            return cached
        }
        lock.lock()
        missesCellParse += 1
        lock.unlock()
        return nil
    }

    func storeCellParse(contentHash: Int, isHeader: Bool, attributedString: NSAttributedString) {
        let key = CellParseCacheKey(contentHash: contentHash, isHeader: isHeader)
        cellParseCache.setObject(attributedString, forKey: key)
    }

    private func evictIfNeeded() {
        let total = intrinsicCache.count + heightCache.count
        guard total > maxEntries else { return }

        let removeTarget = total - maxEntries + maxEntries / 4

        var allAccess: [AccessRecord] = []
        allAccess.reserveCapacity(total)
        for (key, entry) in intrinsicCache {
            allAccess.append(AccessRecord(isIntrinsic: true, access: entry.lastAccess, intrinsicKey: key, heightKey: nil))
        }
        for (key, entry) in heightCache {
            allAccess.append(AccessRecord(isIntrinsic: false, access: entry.lastAccess, intrinsicKey: nil, heightKey: key))
        }
        allAccess.sort { $0.access < $1.access }

        let toRemove = min(removeTarget, allAccess.count)
        for i in 0..<toRemove {
            let item = allAccess[i]
            if item.isIntrinsic, let key = item.intrinsicKey {
                intrinsicCache.removeValue(forKey: key)
            } else if let key = item.heightKey {
                heightCache.removeValue(forKey: key)
            }
            evictions += 1
        }
    }

    private var totalCount: Int {
        intrinsicCache.count + heightCache.count
    }

    func logStats(context: String) {
        lock.lock()
        defer { lock.unlock() }

        let totalHits = hitsIntrinsic + hitsHeight
        let totalMisses = missesIntrinsic + missesHeight
        let totalRequests = totalHits + totalMisses
        let hitRate = totalRequests == 0 ? 0 : (Double(totalHits) / Double(totalRequests)) * 100.0
        let cellParseTotal = hitsCellParse + missesCellParse
        let cellParseRate = cellParseTotal == 0 ? 0 : (Double(hitsCellParse) / Double(cellParseTotal)) * 100.0

        MarkdownLogger.debug(.table, "sizeCache \(context) entries=\(totalCount)/\(maxEntries) layout=\(layoutCache.count)/\(maxLayoutEntries) cellParseHitRate=\(String(format: "%.1f", cellParseRate))% hits=\(totalHits) misses=\(totalMisses) hitRate=\(String(format: "%.1f", hitRate))% layoutHits=\(hitsLayout) layoutMisses=\(missesLayout) cellParseHits=\(hitsCellParse) cellParseMisses=\(missesCellParse) evictions=\(evictions)")
    }
    
    func clearAll() {
        lock.lock()
        defer { lock.unlock() }
        
        let count = intrinsicCache.count + heightCache.count + layoutCache.count
        intrinsicCache.removeAll()
        heightCache.removeAll()
        layoutCache.removeAll()
        cellParseCache.removeAllObjects()
        accessCounter = 0
        
        MarkdownLogger.debug(.table, "sizeCache clearAll evicted=\(count) (cellParseCache auto-managed)")
    }
    
    @objc private func handleMemoryWarning() {
        clearAll()
        MarkdownLogger.warning(.table, "sizeCache memory warning: cleared all caches")
    }
}
