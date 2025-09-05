import Foundation

/// 简单的输入分类器 - 基于基本规则判断用户输入是命令还是自然语言
public final class SimpleInputClassifier: @unchecked Sendable {
    
    public enum InputType {
        case command      // 直接执行的命令
        case naturalLanguage    // 需要AI处理的自然语言
    }
    
    public struct ClassificationResult {
        public let type: InputType
        public let confidence: Double
        public let reason: String
        
        public init(type: InputType, confidence: Double, reason: String) {
            self.type = type
            self.confidence = confidence
            self.reason = reason
        }
    }
    
    public init() {}
    
    /// 分类用户输入
    public func classify(_ input: String) -> ClassificationResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 空输入
        if trimmed.isEmpty {
            return ClassificationResult(type: .command, confidence: 0.5, reason: "Empty input")
        }
        
        // 1. 检查中文字符（最直接的自然语言标识）
        if containsChineseCharacters(trimmed) && !isProperlyQuoted(trimmed) {
            return ClassificationResult(type: .naturalLanguage, confidence: 0.95, reason: "Contains Chinese characters")
        }
        
        // 2. 检查英文自然语言关键词（未在引号中）
        if containsUnquotedNaturalLanguage(trimmed) {
            return ClassificationResult(type: .naturalLanguage, confidence: 0.8, reason: "Contains natural language keywords")
        }
        
        // 3. 默认当作命令处理
        return ClassificationResult(type: .command, confidence: 0.7, reason: "Default to command")
    }
    
    // MARK: - Private Methods
    
    private func containsChineseCharacters(_ input: String) -> Bool {
        return input.range(of: "\\p{Han}", options: .regularExpression) != nil
    }
    
    private func isProperlyQuoted(_ input: String) -> Bool {
        // 检查是否被引号包围（简单版本）
        let quotedPatterns = [
            #"^".*"$"#,           // 双引号包围
            #"^'.*'$"#,           // 单引号包围
            #"echo\s+["']"#,      // echo命令开头
            #"git.*-m\s+["']"#    // git commit消息
        ]
        
        return quotedPatterns.contains { pattern in
            input.range(of: pattern, options: .regularExpression) != nil
        }
    }
    
    private func containsUnquotedNaturalLanguage(_ input: String) -> Bool {
        let lowerInput = input.lowercased()
        
        // 基本的英文自然语言关键词
        let naturalLanguageKeywords = [
            "how to", "what is", "why", "how do i", "can you",
            "help me", "show me", "tell me", "find me", "explain",
            "list all", "get all", "display all"
        ]
        
        for keyword in naturalLanguageKeywords {
            if lowerInput.contains(keyword) {
                // 简单检查是否在引号中
                if !isKeywordInQuotes(input, keyword: keyword) {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func isKeywordInQuotes(_ input: String, keyword: String) -> Bool {
        // 改进版：检测 keyword 是否出现在任意引号包裹的范围内
        let quotedSegments = findQuotedSegments(in: input)
        
        // 在小写版本中查找关键词出现位置，再映射到原字符串的索引范围
        let lowerInput = input.lowercased()
        let lowerKeyword = keyword.lowercased()
        
        var searchStart = lowerInput.startIndex
        while let range = lowerInput.range(of: lowerKeyword, range: searchStart..<lowerInput.endIndex) {
            // 将 lowercased 的索引范围映射回原字符串索引（同长度映射）
            let startOffset = lowerInput.distance(from: lowerInput.startIndex, to: range.lowerBound)
            let endOffset = lowerInput.distance(from: lowerInput.startIndex, to: range.upperBound)
            let startIndex = input.index(input.startIndex, offsetBy: startOffset)
            let endIndex = input.index(input.startIndex, offsetBy: endOffset)
            let originalRange = startIndex..<endIndex
            
            // 判断该范围是否被任意引号段包含
            for q in quotedSegments {
                if q.contains(originalRange.lowerBound) && q.contains(originalRange.upperBound) {
                    return true
                }
            }
            
            // 继续向后查找
            searchStart = range.upperBound
        }
        
        return false
    }
    
    private func findQuotedSegments(in input: String) -> [Range<String.Index>] {
        var segments: [Range<String.Index>] = []
        var inDoubleQuotes = false
        var inSingleQuotes = false
        var currentStart: String.Index? = nil
        var i = input.startIndex
        
        while i < input.endIndex {
            let c = input[i]
            
            if c == "\\" { // 跳过转义的下一个字符
                i = input.index(after: i)
                if i < input.endIndex { i = input.index(after: i) }
                continue
            }
            
            if c == "\"" && !inSingleQuotes {
                if inDoubleQuotes {
                    // 结束双引号段
                    if let start = currentStart {
                        let endExclusive = input.index(after: i)
                        segments.append(start..<endExclusive)
                    }
                    inDoubleQuotes = false
                    currentStart = nil
                } else {
                    // 开始双引号段
                    inDoubleQuotes = true
                    currentStart = i
                }
                i = input.index(after: i)
                continue
            }
            
            if c == "'" && !inDoubleQuotes {
                if inSingleQuotes {
                    // 结束单引号段
                    if let start = currentStart {
                        let endExclusive = input.index(after: i)
                        segments.append(start..<endExclusive)
                    }
                    inSingleQuotes = false
                    currentStart = nil
                } else {
                    // 开始单引号段
                    inSingleQuotes = true
                    currentStart = i
                }
                i = input.index(after: i)
                continue
            }
            
            i = input.index(after: i)
        }
        
        return segments
    }
}
