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

    private let lock = NSLock()
    private var intrinsicCache: [IntrinsicKey: IntrinsicEntry] = [:]
    private var heightCache: [HeightKey: HeightEntry] = [:]
    private var accessCounter: UInt64 = 0
    private let maxEntries: Int
    private var hitsIntrinsic: UInt64 = 0
    private var hitsHeight: UInt64 = 0
    private var missesIntrinsic: UInt64 = 0
    private var missesHeight: UInt64 = 0
    private var evictions: UInt64 = 0

    public init(maxEntries: Int = 800) {
        self.maxEntries = maxEntries
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

    private func evictIfNeeded() {
        while totalCount > maxEntries {
            var oldestIntrinsic: (key: IntrinsicKey, access: UInt64)?
            for (key, value) in intrinsicCache {
                if oldestIntrinsic == nil || value.lastAccess < oldestIntrinsic!.access {
                    oldestIntrinsic = (key, value.lastAccess)
                }
            }

            var oldestHeight: (key: HeightKey, access: UInt64)?
            for (key, value) in heightCache {
                if oldestHeight == nil || value.lastAccess < oldestHeight!.access {
                    oldestHeight = (key, value.lastAccess)
                }
            }

            if let oldestIntrinsic = oldestIntrinsic, let oldestHeight = oldestHeight {
                if oldestIntrinsic.access <= oldestHeight.access {
                    intrinsicCache.removeValue(forKey: oldestIntrinsic.key)
                    evictions += 1
                } else {
                    heightCache.removeValue(forKey: oldestHeight.key)
                    evictions += 1
                }
            } else if let oldestIntrinsic = oldestIntrinsic {
                intrinsicCache.removeValue(forKey: oldestIntrinsic.key)
                evictions += 1
            } else if let oldestHeight = oldestHeight {
                heightCache.removeValue(forKey: oldestHeight.key)
                evictions += 1
            } else {
                break
            }
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

        MarkdownLogger.debug(.table, "sizeCache \(context) entries=\(totalCount)/\(maxEntries) hits=\(totalHits) misses=\(totalMisses) hitRate=\(String(format: "%.1f", hitRate))% evictions=\(evictions)")
    }
}
