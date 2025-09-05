#!/usr/bin/env swift

// Code Review Checklist - 自动化检查脚本
// 用法: swift Scripts/code_review_check.swift

import Foundation

// MARK: - 颜色输出

enum Color: String {
    case red = "\u{001B}[0;31m"
    case green = "\u{001B}[0;32m"
    case yellow = "\u{001B}[0;33m"
    case blue = "\u{001B}[0;34m"
    case reset = "\u{001B}[0;0m"
    
    func wrap(_ text: String) -> String {
        return "\(self.rawValue)\(text)\(Color.reset.rawValue)"
    }
}

// MARK: - 检查项

struct CheckItem {
    let category: String
    let name: String
    let check: () -> Bool
    let severity: Severity
    
    enum Severity {
        case error   // 必须修复
        case warning // 强烈建议修复
        case info    // 建议改进
    }
}

class CodeReviewer {
    
    private var passedChecks = 0
    private var failedChecks = 0
    private var warnings = 0
    
    // MARK: - 执行检查
    
    func runAllChecks() {
        print(Color.blue.wrap("\n🔍 SSHAIClient 代码审查检查\n"))
        print("基于 TECHNICAL_SPECIFICATION.md v1.0")
        print("=" * 50)
        
        let checks: [CheckItem] = [
            // 架构检查
            CheckItem(
                category: "架构",
                name: "检查是否存在跨层依赖",
                check: checkLayerDependencies,
                severity: .error
            ),
            CheckItem(
                category: "架构",
                name: "检查 Repository 模式实现",
                check: checkRepositoryPattern,
                severity: .warning
            ),
            
            // 命名检查
            CheckItem(
                category: "命名",
                name: "检查模型命名规范",
                check: checkModelNaming,
                severity: .error
            ),
            CheckItem(
                category: "命名",
                name: "检查文件组织结构",
                check: checkFileOrganization,
                severity: .warning
            ),
            
            // 安全检查
            CheckItem(
                category: "安全",
                name: "检查硬编码密钥",
                check: checkHardcodedSecrets,
                severity: .error
            ),
            CheckItem(
                category: "安全",
                name: "检查加密实现",
                check: checkEncryption,
                severity: .error
            ),
            
            // 代码质量
            CheckItem(
                category: "质量",
                name: "检查强制解包",
                check: checkForceUnwrapping,
                severity: .error
            ),
            CheckItem(
                category: "质量",
                name: "检查错误处理",
                check: checkErrorHandling,
                severity: .warning
            ),
            
            // 测试
            CheckItem(
                category: "测试",
                name: "检查测试覆盖",
                check: checkTestCoverage,
                severity: .info
            ),
            
            // 异步
            CheckItem(
                category: "异步",
                name: "检查 async/await 使用",
                check: checkAsyncAwait,
                severity: .warning
            ),
            CheckItem(
                category: "异步",
                name: "检查 @MainActor 使用",
                check: checkMainActor,
                severity: .warning
            )
        ]
        
        var errorCount = 0
        var currentCategory = ""
        
        for check in checks {
            if check.category != currentCategory {
                currentCategory = check.category
                print("\n\(Color.blue.wrap("[\(check.category)]"))")
            }
            
            let passed = check.check()
            let icon = passed ? "✅" : (check.severity == .error ? "❌" : "⚠️")
            let status = passed ? Color.green.wrap("PASS") : 
                        (check.severity == .error ? Color.red.wrap("FAIL") : Color.yellow.wrap("WARN"))
            
            print("  \(icon) \(check.name): \(status)")
            
            if passed {
                passedChecks += 1
            } else {
                if check.severity == .error {
                    failedChecks += 1
                    errorCount += 1
                } else {
                    warnings += 1
                }
            }
        }
        
        // 打印总结
        printSummary(errorCount: errorCount)
    }
    
    // MARK: - 具体检查实现
    
    private func checkLayerDependencies() -> Bool {
        // 检查 View 层是否直接访问数据层
        let viewFiles = findFiles(pattern: "*View.swift", in: "Sources/SSHAIClient/UI")
        
        for file in viewFiles {
            if let content = try? String(contentsOfFile: file) {
                if content.contains("LocalDataManager") || 
                   content.contains("SQLite") ||
                   content.contains("import SQLite") {
                    print(Color.red.wrap("    ⚠️  发现跨层依赖: \(file)"))
                    return false
                }
            }
        }
        return true
    }
    
    private func checkRepositoryPattern() -> Bool {
        // 检查是否有 Repository 实现
        let repoFiles = findFiles(pattern: "*Repository.swift", in: "Sources/SSHAIClient")
        return !repoFiles.isEmpty
    }
    
    private func checkModelNaming() -> Bool {
        // 检查存储模型命名
        let dataFiles = findFiles(pattern: "*.swift", in: "Sources/SSHAIClient/Core/Data")
        
        for file in dataFiles {
            if let content = try? String(contentsOfFile: file) {
                // 检查是否使用了正确的命名模式
                if content.contains("struct SSHConnection") && 
                   !content.contains("struct StoredConnection") {
                    print(Color.yellow.wrap("    ⚠️  数据层应使用 StoredConnection: \(file)"))
                    return false
                }
            }
        }
        return true
    }
    
    private func checkFileOrganization() -> Bool {
        // 检查目录结构
        let expectedDirs = [
            "Sources/SSHAIClient/UI/Views",
            "Sources/SSHAIClient/Features",
            "Sources/SSHAIClient/Core"
        ]
        
        for dir in expectedDirs {
            if !FileManager.default.fileExists(atPath: dir) {
                print(Color.yellow.wrap("    ⚠️  缺少目录: \(dir)"))
                return false
            }
        }
        return true
    }
    
    private func checkHardcodedSecrets() -> Bool {
        // 检查硬编码的密钥和密码
        let allFiles = findFiles(pattern: "*.swift", in: "Sources")
        let secretPatterns = [
            "password\\s*=\\s*\"[^\"]+\"",
            "apiKey\\s*=\\s*\"[^\"]+\"",
            "secret\\s*=\\s*\"[^\"]+\"",
            "token\\s*=\\s*\"[^\"]+\""
        ]
        
        for file in allFiles {
            if let content = try? String(contentsOfFile: file) {
                for pattern in secretPatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                        let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
                        if !matches.isEmpty {
                            // 排除测试文件和 Mock
                            if !file.contains("Test") && !file.contains("Mock") {
                                print(Color.red.wrap("    ⚠️  发现硬编码密钥: \(file)"))
                                return false
                            }
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func checkEncryption() -> Bool {
        // 检查 LocalDataManager 是否实现了加密
        let dataManager = "Sources/SSHAIClient/Core/Data/LocalDataManager.swift"
        
        if let content = try? String(contentsOfFile: dataManager) {
            return content.contains("CryptoKit") || content.contains("AES.GCM")
        }
        return false
    }
    
    private func checkForceUnwrapping() -> Bool {
        // 检查强制解包
        let allFiles = findFiles(pattern: "*.swift", in: "Sources")
        var foundIssues = false
        
        for file in allFiles {
            if let content = try? String(contentsOfFile: file) {
                // 简单的强制解包检查（排除测试文件）
                if !file.contains("Test") {
                    let lines = content.components(separatedBy: .newlines)
                    for (index, line) in lines.enumerated() {
                        // 检查 ! 但排除类型声明和否定
                        if line.contains("!") && 
                           !line.contains("!=") && 
                           !line.contains("!.") &&
                           !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") {
                            // 简单检查是否是强制解包
                            if line.contains(".!") || line.contains("]!") || line.contains(")!") {
                                print(Color.yellow.wrap("    ⚠️  可能的强制解包 [\(file):\(index + 1)]"))
                                foundIssues = true
                            }
                        }
                    }
                }
            }
        }
        return !foundIssues
    }
    
    private func checkErrorHandling() -> Bool {
        // 检查是否有 try! 或忽略的错误
        let allFiles = findFiles(pattern: "*.swift", in: "Sources")
        
        for file in allFiles {
            if !file.contains("Test") {
                if let content = try? String(contentsOfFile: file) {
                    if content.contains("try!") {
                        print(Color.red.wrap("    ⚠️  发现 try! 强制尝试: \(file)"))
                        return false
                    }
                    if content.contains("_ = try?") {
                        print(Color.yellow.wrap("    ⚠️  发现忽略的错误: \(file)"))
                        return false
                    }
                }
            }
        }
        return true
    }
    
    private func checkTestCoverage() -> Bool {
        // 简单检查测试文件是否存在
        let testFiles = findFiles(pattern: "*Tests.swift", in: "Tests")
        let sourceFiles = findFiles(pattern: "*.swift", in: "Sources")
        
        let ratio = Double(testFiles.count) / Double(sourceFiles.count)
        if ratio < 0.3 {
            print(Color.yellow.wrap("    ⚠️  测试覆盖率偏低: \(Int(ratio * 100))%"))
            return false
        }
        return true
    }
    
    private func checkAsyncAwait() -> Bool {
        // 检查是否使用现代异步模式
        let viewModelFiles = findFiles(pattern: "*ViewModel.swift", in: "Sources")
        
        for file in viewModelFiles {
            if let content = try? String(contentsOfFile: file) {
                // 检查是否还在使用旧的完成处理器
                if content.contains("completion:") && content.contains("@escaping") {
                    print(Color.yellow.wrap("    ⚠️  建议使用 async/await: \(file)"))
                    return false
                }
            }
        }
        return true
    }
    
    private func checkMainActor() -> Bool {
        // 检查 ViewModel 是否正确使用 @MainActor
        let viewModelFiles = findFiles(pattern: "*ViewModel.swift", in: "Sources")
        
        for file in viewModelFiles {
            if let content = try? String(contentsOfFile: file) {
                // 检查包含 @Published 的类是否有 @MainActor
                if content.contains("@Published") && !content.contains("@MainActor") {
                    print(Color.yellow.wrap("    ⚠️  ViewModel 应使用 @MainActor: \(file)"))
                    return false
                }
            }
        }
        return true
    }
    
    // MARK: - 辅助方法
    
    private func findFiles(pattern: String, in directory: String) -> [String] {
        var files: [String] = []
        
        if let enumerator = FileManager.default.enumerator(atPath: directory) {
            for case let file as String in enumerator {
                if file.hasSuffix(".swift") {
                    if pattern.contains("*") {
                        let filePattern = pattern.replacingOccurrences(of: "*", with: "")
                        if file.contains(filePattern) {
                            files.append("\(directory)/\(file)")
                        }
                    } else if file == pattern {
                        files.append("\(directory)/\(file)")
                    }
                }
            }
        }
        
        return files
    }
    
    private func printSummary(errorCount: Int) {
        print("\n" + "=" * 50)
        print(Color.blue.wrap("📊 检查结果总结\n"))
        
        print("  ✅ 通过: \(Color.green.wrap("\(passedChecks)"))")
        print("  ❌ 失败: \(Color.red.wrap("\(failedChecks)"))")
        print("  ⚠️  警告: \(Color.yellow.wrap("\(warnings)"))")
        
        print("\n" + "=" * 50)
        
        if errorCount > 0 {
            print(Color.red.wrap("\n❌ 代码审查未通过！"))
            print(Color.red.wrap("   请修复 \(errorCount) 个错误后再提交。"))
            print("\n📖 请参考 TECHNICAL_SPECIFICATION.md 了解详细规范")
            exit(1)
        } else if warnings > 0 {
            print(Color.yellow.wrap("\n⚠️  代码审查通过，但有 \(warnings) 个警告"))
            print(Color.yellow.wrap("   建议在下次迭代中改进"))
            print("\n✅ 可以提交，但请考虑修复警告项")
        } else {
            print(Color.green.wrap("\n🎉 完美！代码审查全部通过！"))
            print(Color.green.wrap("   代码质量优秀，符合所有规范"))
        }
    }
}

// MARK: - String 扩展

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}

// MARK: - 主程序

let reviewer = CodeReviewer()
reviewer.runAllChecks()
