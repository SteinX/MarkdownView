import UIKit
import ImageIO

public struct ImageCacheConfig {
    public var memoryCacheSizeMB: Int?
    public var diskCacheSizeMB: Int
    public var diskCacheDirectory: String

    public init(memoryCacheSizeMB: Int? = nil, diskCacheSizeMB: Int = 100, diskCacheDirectory: String = "MarkdownImages") {
        self.memoryCacheSizeMB = memoryCacheSizeMB
        self.diskCacheSizeMB = diskCacheSizeMB
        self.diskCacheDirectory = diskCacheDirectory
    }

    public static let `default` = ImageCacheConfig()
}

public final class ImageCache {
    public static let shared = ImageCache()

    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let ioQueue = DispatchQueue(label: "com.markdown.imagecache.io", qos: .utility)

    private var diskCacheURL: URL
    private var config: ImageCacheConfig
    private var diskCacheSize: Int = 0
    private var diskFileAccess: [String: Date] = [:]

    public init(config: ImageCacheConfig = .default) {
        self.config = config

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheURL = caches.appendingPathComponent(config.diskCacheDirectory, isDirectory: true)
        ensureDiskDirectory()

        configureMemoryCache()
        calculateDiskCacheSize()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    public func configure(_ config: ImageCacheConfig) {
        ioQueue.async { [weak self] in
            guard let self = self else { return }

            let directoryChanged = self.config.diskCacheDirectory != config.diskCacheDirectory
            self.config = config

            self.configureMemoryCache()

            if directoryChanged {
                let caches = self.fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
                self.diskCacheURL = caches.appendingPathComponent(config.diskCacheDirectory, isDirectory: true)
                self.ensureDiskDirectory()
                self.calculateDiskCacheSize()
            }

            self.evictDiskCacheIfNeeded()
        }
    }

    public func image(for url: URL, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let memoryKey = memoryCacheKey(for: url, size: targetSize)

        if let cached = memoryCache.object(forKey: memoryKey as NSString) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        ioQueue.async { [weak self] in
            guard let self = self else { return }

            if url.isFileURL {
                if let thumbnail = self.downsample(fileURL: url, to: targetSize) {
                    let cost = self.imageCost(thumbnail)
                    self.memoryCache.setObject(thumbnail, forKey: memoryKey as NSString, cost: cost)
                    DispatchQueue.main.async { completion(thumbnail) }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
                return
            }

            let diskKey = self.diskCacheKey(for: url)
            let diskURL = self.diskCacheURL.appendingPathComponent(diskKey)

            if self.fileManager.fileExists(atPath: diskURL.path) {
                if let thumbnail = self.downsample(fileURL: diskURL, to: targetSize) {
                    self.touchFile(diskKey)
                    let cost = self.imageCost(thumbnail)
                    self.memoryCache.setObject(thumbnail, forKey: memoryKey as NSString, cost: cost)
                    DispatchQueue.main.async { completion(thumbnail) }
                    return
                }
            }

            self.download(url: url, targetSize: targetSize, memoryKey: memoryKey, diskKey: diskKey, completion: completion)
        }
    }

    public func clearMemoryCache() {
        ioQueue.async { [weak self] in
            self?.memoryCache.removeAllObjects()
        }
    }

    public func clearAll() {
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            self.memoryCache.removeAllObjects()
            try? self.fileManager.removeItem(at: self.diskCacheURL)
            self.ensureDiskDirectory()
            self.diskCacheSize = 0
            self.diskFileAccess.removeAll()
        }
    }

    public var currentDiskCacheSize: Int {
        ioQueue.sync {
            diskCacheSize
        }
    }

    private func configureMemoryCache() {
        let memoryMB: Int
        if let override = config.memoryCacheSizeMB {
            memoryMB = override
        } else {
            let memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
            switch memoryGB {
            case ..<4.0:
                memoryMB = 50
            case 4.0..<8.0:
                memoryMB = 100
            default:
                memoryMB = 200
            }
        }

        memoryCache.totalCostLimit = memoryMB * 1024 * 1024
        memoryCache.countLimit = 100
    }

    private func ensureDiskDirectory() {
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }

    private func memoryCacheKey(for url: URL, size: CGSize) -> String {
        "\(url.absoluteString)_\(Int(size.width))x\(Int(size.height))"
    }

    private func diskCacheKey(for url: URL) -> String {
        let base = url.absoluteString.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        let safe = base.replacingOccurrences(of: "/", with: "_")
        return String(safe.prefix(120))
    }

    private func download(url: URL, targetSize: CGSize, memoryKey: String, diskKey: String, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            let diskURL = self.diskCacheURL.appendingPathComponent(diskKey)
            let existingSize = (try? self.fileManager.attributesOfItem(atPath: diskURL.path)[.size] as? Int) ?? 0
            do {
                try data.write(to: diskURL, options: .atomic)
                self.ioQueue.async { [weak self] in
                    self?.updateDiskCacheMetadata(for: diskKey, fileURL: diskURL, previousSize: existingSize)
                }
            } catch {
                // Ignore disk cache errors
            }

            if let thumbnail = self.downsample(data: data, to: targetSize) {
                let cost = self.imageCost(thumbnail)
                self.memoryCache.setObject(thumbnail, forKey: memoryKey as NSString, cost: cost)
                DispatchQueue.main.async { completion(thumbnail) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    private func updateDiskCacheMetadata(for key: String, fileURL: URL, previousSize: Int) {
        if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
           let size = attrs[.size] as? Int {
            diskCacheSize += max(0, size - previousSize)
        }
        touchFile(key)
        evictDiskCacheIfNeeded()
    }

    private func touchFile(_ filename: String) {
        let now = Date()
        diskFileAccess[filename] = now
        let fileURL = diskCacheURL.appendingPathComponent(filename)
        try? fileManager.setAttributes([.modificationDate: now], ofItemAtPath: fileURL.path)
    }

    private func calculateDiskCacheSize() {
        diskCacheSize = 0
        diskFileAccess.removeAll()

        guard let contents = try? fileManager.contentsOfDirectory(atPath: diskCacheURL.path) else { return }
        for filename in contents {
            let fileURL = diskCacheURL.appendingPathComponent(filename)
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path) {
                if let size = attrs[.size] as? Int {
                    diskCacheSize += size
                }
                if let modDate = attrs[.modificationDate] as? Date {
                    diskFileAccess[filename] = modDate
                }
            }
        }
    }

    private func evictDiskCacheIfNeeded() {
        let maxSize = config.diskCacheSizeMB * 1024 * 1024
        guard diskCacheSize > maxSize else { return }

        let sorted = diskFileAccess.sorted { $0.value < $1.value }
        for (filename, _) in sorted {
            guard diskCacheSize > maxSize else { break }

            let fileURL = diskCacheURL.appendingPathComponent(filename)
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let fileSize = attrs[.size] as? Int {
                try? fileManager.removeItem(at: fileURL)
                diskCacheSize -= fileSize
                diskFileAccess.removeValue(forKey: filename)
            }
        }
    }

    private func downsample(fileURL: URL, to targetSize: CGSize) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, options as CFDictionary) else {
            return nil
        }
        return downsample(source: source, to: targetSize)
    }

    private func downsample(data: Data, to targetSize: CGSize) -> UIImage? {
        let options: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return nil
        }
        return downsample(source: source, to: targetSize)
    }

    private func downsample(source: CGImageSource, to targetSize: CGSize) -> UIImage? {
        let maxDimension = max(targetSize.width, targetSize.height) * UIScreen.main.scale

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    private func imageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }

    @objc private func handleMemoryWarning() {
        ioQueue.async { [weak self] in
            self?.memoryCache.removeAllObjects()
        }
    }
}
