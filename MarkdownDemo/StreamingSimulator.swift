import Foundation

class StreamingSimulator {
    private var fullText: String
    private var currentIndex: String.Index
    private var timer: Timer?
    private var onUpdate: ((String) -> Void)?
    private var onComplete: (() -> Void)?
    
    private(set) var currentText: String = ""
    private(set) var isStreaming: Bool = false
    
    init(text: String) {
        self.fullText = text
        self.currentIndex = text.startIndex
    }
    
    func start(onUpdate: @escaping (String) -> Void, onComplete: @escaping () -> Void) {
        guard !isStreaming else { return }
        
        self.onUpdate = onUpdate
        self.onComplete = onComplete
        self.isStreaming = true
        self.currentText = ""
        self.currentIndex = fullText.startIndex
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        isStreaming = false
    }
    
    private func tick() {
        guard currentIndex < fullText.endIndex else {
            stop()
            onComplete?()
            return
        }
        
        // Randomly determine how many characters to append (1 to 3) to simulate typing variation
        let chunkSize = Int.random(in: 1...3)
        
        for _ in 0..<chunkSize {
            if currentIndex < fullText.endIndex {
                currentText.append(fullText[currentIndex])
                currentIndex = fullText.index(after: currentIndex)
            }
        }
        
        onUpdate?(currentText)
    }
}
