import UIKit

/// Manages streaming mode throttling for MarkdownView.
/// Coalesces rapid updates to reduce CPU usage during real-time content generation.
final class StreamingManager {
    // MARK: - Configuration
    var throttleInterval: TimeInterval = 0.1
    var isEnabled: Bool = false {
        didSet {
            if !isEnabled && oldValue {
                finalizeRender()
            }
        }
    }
    
    // MARK: - State
    private(set) var pendingContent: String?
    private var throttleTimer: Timer?
    private var throttleWindowDeadline: CFTimeInterval = 0
    private var lastExecutedContent: String?
    private var lastExecutedWidth: CGFloat = 0
    private var lastInputVersion: Int = -1
    
    // MARK: - Callbacks
    var onExecuteRender: (() -> Void)?
    var shouldSkipRender: ((String, CGFloat, Int) -> Bool)?
    
    // MARK: - Scheduling
    
    /// Schedule a throttled render for new content.
    /// Returns true if render was executed immediately, false if scheduled for later.
    @discardableResult
    func scheduleRender(content: String, width: CGFloat, inputVersion: Int) -> Bool {
        // Skip if content identical to pending
        if pendingContent == content {
            return false
        }
        
        // Skip if equivalent to last rendered
        if let shouldSkip = shouldSkipRender?(content, width, inputVersion), shouldSkip {
            return false
        }
        
        pendingContent = content
        
        // Already have a timer scheduled
        if throttleTimer != nil {
            return false
        }
        
        let now = CACurrentMediaTime()
        
        // Outside throttle window - execute immediately
        if now >= throttleWindowDeadline {
            executeRender()
            throttleWindowDeadline = now + throttleInterval
            return true
        }
        
        // Schedule for next window
        let delay = throttleWindowDeadline - now
        if delay <= 0 {
            executeRender()
            throttleWindowDeadline = CACurrentMediaTime() + throttleInterval
            return true
        }
        
        throttleTimer = Timer.scheduledTimer(
            withTimeInterval: delay,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            self.executeRender()
            self.throttleWindowDeadline = CACurrentMediaTime() + self.throttleInterval
        }
        
        return false
    }
    
    /// Force immediate execution of pending render.
    func executeRender() {
        guard pendingContent != nil else {
            throttleTimer = nil
            return
        }
        
        lastExecutedContent = pendingContent
        pendingContent = nil
        throttleTimer = nil
        
        onExecuteRender?()
    }
    
    /// Finalize streaming mode and clean up.
    func finalizeRender() {
        throttleTimer?.invalidate()
        throttleTimer = nil
        throttleWindowDeadline = 0
        
        if pendingContent != nil {
            pendingContent = nil
            onExecuteRender?()
        }
    }
    
    /// Reset all state.
    func reset() {
        throttleTimer?.invalidate()
        throttleTimer = nil
        pendingContent = nil
        lastExecutedContent = nil
        lastExecutedWidth = 0
        throttleWindowDeadline = 0
        lastInputVersion = -1
    }
    
    /// Update execution tracking state.
    func markExecuted(content: String, width: CGFloat, inputVersion: Int) {
        lastExecutedContent = content
        lastExecutedWidth = width
        lastInputVersion = inputVersion
    }
    
    /// Check if content would be equivalent to last execution.
    func isEquivalentToLastExecution(content: String, width: CGFloat, inputVersion: Int) -> Bool {
        return content == lastExecutedContent
            && abs(width - lastExecutedWidth) <= 0.5
            && inputVersion == lastInputVersion
    }
}
