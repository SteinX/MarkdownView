import Foundation

/// Analyzes markdown to detect unclosed code blocks for smart highlighting during streaming
public struct CodeBlockAnalyzer {
    
    /// State of code blocks in markdown content
    public struct CodeBlockState {
        /// Whether there is an unclosed code block
        public let hasUnclosedBlock: Bool
        
        /// Language identifier of the unclosed block (if any)
        public let unclosedLanguage: String?
        
        /// Line number where the unclosed block starts (1-based)
        public let unclosedStartLine: Int?
        
        /// Total number of code blocks found (both closed and unclosed)
        public let totalCodeBlocks: Int
        
        public static let empty = CodeBlockState(
            hasUnclosedBlock: false,
            unclosedLanguage: nil,
            unclosedStartLine: nil,
            totalCodeBlocks: 0
        )
    }
    
    /// Analyze markdown content to detect unclosed code blocks
    /// Uses state machine to track fence opening/closing
    public static func analyze(_ markdown: String) -> CodeBlockState {
        guard !markdown.isEmpty else {
            MarkdownLogger.verbose(.streaming, "analyze skipped, empty markdown")
            return .empty
        }
        
        let result: CodeBlockState = MarkdownLogger.measure(.streaming, "analyze codeBlocks") {
            let lines = markdown.components(separatedBy: .newlines)
            var isInCodeBlock = false
            var currentFence = ""
            var currentLanguage: String?
            var unclosedStartLine: Int?
            var totalBlocks = 0
            
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Detect code fence (``` or ~~~)
                if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                    let fence = String(trimmed.prefix(3))
                    
                    if !isInCodeBlock {
                        // Opening fence
                        isInCodeBlock = true
                        currentFence = fence
                        unclosedStartLine = index + 1
                        
                        // Extract language identifier
                        let afterFence = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                        currentLanguage = afterFence.isEmpty ? nil : String(afterFence)
                        
                    } else if trimmed.hasPrefix(currentFence) {
                        // Closing fence (must match opening fence type)
                        isInCodeBlock = false
                        currentFence = ""
                        currentLanguage = nil
                        unclosedStartLine = nil
                        totalBlocks += 1
                    }
                }
            }
            
            // If still in code block at end, it's unclosed
            if isInCodeBlock {
                totalBlocks += 1 // Count the unclosed block
                return CodeBlockState(
                    hasUnclosedBlock: true,
                    unclosedLanguage: currentLanguage,
                    unclosedStartLine: unclosedStartLine,
                    totalCodeBlocks: totalBlocks
                )
            }
            
            return CodeBlockState(
                hasUnclosedBlock: false,
                unclosedLanguage: nil,
                unclosedStartLine: nil,
                totalCodeBlocks: totalBlocks
            )
        }
        
        MarkdownLogger.debug(.streaming, "analyze result: unclosed=\(result.hasUnclosedBlock), total=\(result.totalCodeBlocks)")
        
        return result
    }
}
