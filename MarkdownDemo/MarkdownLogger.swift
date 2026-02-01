import Foundation
import os.log

// MARK: - Log Level

/// 日志级别，值越大输出越详细
public enum MarkdownLogLevel: Int, Comparable, Sendable {
    case off = 0      // 关闭所有日志
    case error = 1    // 仅严重错误
    case warning = 2  // 警告 + 错误
    case info = 3     // 一般信息
    case debug = 4    // 调试信息 (含性能计时)
    case verbose = 5  // 详细跟踪
    
    public static func < (lhs: MarkdownLogLevel, rhs: MarkdownLogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var osLogType: OSLogType {
        switch self {
        case .off: return .default
        case .error: return .error
        case .warning: return .default  // os_log 没有 warning 类型
        case .info: return .info
        case .debug: return .debug
        case .verbose: return .debug
        }
    }
}

// MARK: - Log Category

/// 日志分类，对应框架内不同模块
public enum MarkdownLogCategory: String, CaseIterable {
    case parser      = "Parser"       // AST 解析
    case renderer    = "Renderer"     // 渲染流程
    case view        = "View"         // 主视图
    case codeBlock   = "CodeBlock"    // 代码块
    case quote       = "Quote"        // 引用块
    case table       = "Table"        // 表格
    case image       = "Image"        // 图片加载
    case pool        = "Pool"         // 复用池
    case streaming   = "Streaming"    // 流式渲染
    case layout      = "Layout"       // 布局
}

// MARK: - Logger

/// 内部日志器，封装 os_log
internal struct MarkdownLogger {
    
    /// 全局日志级别 (默认关闭)
    static var level: MarkdownLogLevel = .off
    
    /// Subsystem 标识
    private static let subsystem = "com.app.markdown"
    
    /// 缓存的 OSLog 实例
    private static var loggers: [MarkdownLogCategory: OSLog] = [:]
    
    /// 获取指定 category 的 OSLog 实例
    private static func logger(for category: MarkdownLogCategory) -> OSLog {
        if let cached = loggers[category] {
            return cached
        }
        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        loggers[category] = log
        return log
    }
    
    /// 记录日志
    /// - Parameters:
    ///   - logLevel: 日志级别
    ///   - category: 日志分类
    ///   - message: 日志消息 (使用 @autoclosure 避免不必要的字符串构建)
    static func log(_ logLevel: MarkdownLogLevel, 
                    category: MarkdownLogCategory, 
                    _ message: @autoclosure () -> String) {
        guard level != .off, logLevel <= level else { return }
        
        let osLog = logger(for: category)
        let msg = message()
        
        os_log("%{public}@", log: osLog, type: logLevel.osLogType, msg)
    }
    
    /// 性能计时 (仅在 debug 级别及以上启用)
    /// - Parameters:
    ///   - category: 日志分类
    ///   - operation: 操作名称
    ///   - block: 要计时的代码块
    /// - Returns: 代码块的返回值
    @discardableResult
    static func measure<T>(_ category: MarkdownLogCategory,
                           _ operation: String,
                           block: () throws -> T) rethrows -> T {
        // 仅在 debug 级别及以上才计时
        guard level >= .debug else {
            return try block()
        }
        
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000 // 转换为毫秒
        
        log(.debug, category: category, "\(operation) completed in \(String(format: "%.2f", elapsed))ms")
        
        return result
    }
    
    // MARK: - Convenience Methods
    
    static func error(_ category: MarkdownLogCategory, _ message: @autoclosure () -> String) {
        log(.error, category: category, message())
    }
    
    static func warning(_ category: MarkdownLogCategory, _ message: @autoclosure () -> String) {
        log(.warning, category: category, message())
    }
    
    static func info(_ category: MarkdownLogCategory, _ message: @autoclosure () -> String) {
        log(.info, category: category, message())
    }
    
    static func debug(_ category: MarkdownLogCategory, _ message: @autoclosure () -> String) {
        log(.debug, category: category, message())
    }
    
    static func verbose(_ category: MarkdownLogCategory, _ message: @autoclosure () -> String) {
        log(.verbose, category: category, message())
    }
}
