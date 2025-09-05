import XCTest
@testable import SSHAIClient

final class SimpleInputClassifierTests: XCTestCase {
    
    var classifier: SimpleInputClassifier!
    
    override func setUp() {
        super.setUp()
        classifier = SimpleInputClassifier()
    }
    
    override func tearDown() {
        classifier = nil
        super.tearDown()
    }
    
    // MARK: - 命令分类测试
    
    func testClassify_BasicCommands_ReturnsCommand() {
        let commands = [
            "ls",
            "pwd",
            "ls -la",
            "git status",
            "docker ps",
            "cd ~/projects",
            "grep 'test' file.txt"
        ]
        
        for command in commands {
            let result = classifier.classify(command)
            XCTAssertEqual(result.type, .command, "Should classify '\(command)' as command")
        }
    }
    
    func testClassify_ShellFeatures_ReturnsCommand() {
        let commands = [
            "ls | grep test",           // 管道
            "echo 'hello' > file.txt",  // 重定向
            "cat file1 && cat file2",   // 逻辑操作
            "./run.sh",                 // 执行脚本
            "/usr/bin/env python",      // 绝对路径
        ]
        
        for command in commands {
            let result = classifier.classify(command)
            XCTAssertEqual(result.type, .command, "Should classify '\(command)' as command")
        }
    }
    
    func testClassify_QuotedNaturalLanguage_ReturnsCommand() {
        let commands = [
            #"echo "how are you today?""#,
            #"git commit -m "fix: how to handle errors""#,
            #"grep "what is this" file.txt"#,
            #"'help me with this'"#
        ]
        
        for command in commands {
            let result = classifier.classify(command)
            XCTAssertEqual(result.type, .command, "Should classify quoted natural language '\(command)' as command")
        }
    }
    
    // MARK: - 自然语言分类测试
    
    func testClassify_ChineseText_ReturnsNaturalLanguage() {
        let chineseInputs = [
            "帮我查看系统信息",
            "列出当前目录下的文件",
            "how to 查看进程",
            "显示磁盘使用情况"
        ]
        
        for input in chineseInputs {
            let result = classifier.classify(input)
            XCTAssertEqual(result.type, .naturalLanguage, "Should classify Chinese text '\(input)' as natural language")
            XCTAssertTrue(result.reason.contains("Chinese"), "Reason should mention Chinese characters")
        }
    }
    
    func testClassify_EnglishNaturalLanguage_ReturnsNaturalLanguage() {
        let naturalLanguageInputs = [
            "how to list files",
            "what is the current directory",
            "help me find large files",
            "show me disk usage",
            "can you list all processes",
            "tell me about system info",
            "explain how to use git"
        ]
        
        for input in naturalLanguageInputs {
            let result = classifier.classify(input)
            XCTAssertEqual(result.type, .naturalLanguage, "Should classify '\(input)' as natural language")
        }
    }
    
    func testClassify_QuotedChineseInCommand_ReturnsCommand() {
        let quotedChinese = [
            #"echo "帮我查看系统信息""#,
            #"git commit -m "修复bug""#
        ]
        
        for command in quotedChinese {
            let result = classifier.classify(command)
            XCTAssertEqual(result.type, .command, "Should classify quoted Chinese '\(command)' as command")
        }
    }
    
    // MARK: - 边界情况测试
    
    func testClassify_EmptyInput_ReturnsCommand() {
        let result = classifier.classify("")
        XCTAssertEqual(result.type, .command)
        XCTAssertTrue(result.reason.contains("Empty"))
    }
    
    func testClassify_WhitespaceOnly_ReturnsCommand() {
        let result = classifier.classify("   \n\t   ")
        XCTAssertEqual(result.type, .command)
        XCTAssertTrue(result.reason.contains("Empty"))
    }
    
    func testClassify_AmbiguousInput_HasReasonableDefault() {
        let ambiguousInputs = [
            "test",
            "abc123",
            "file.txt"
        ]
        
        for input in ambiguousInputs {
            let result = classifier.classify(input)
            // 默认策略是当作命令
            XCTAssertEqual(result.type, .command, "Should have reasonable default for ambiguous input '\(input)'")
        }
    }
    
    // MARK: - 置信度测试
    
    func testClassify_ConfidenceValues_AreReasonable() {
        // 高置信度中文
        let chineseResult = classifier.classify("帮我列出文件")
        XCTAssertGreaterThan(chineseResult.confidence, 0.9)
        
        // 中等置信度英文自然语言
        let englishResult = classifier.classify("how to list files")
        XCTAssertGreaterThan(englishResult.confidence, 0.7)
        XCTAssertLessThan(englishResult.confidence, 0.9)
        
        // 较低置信度默认判断
        let defaultResult = classifier.classify("ambiguous")
        XCTAssertLessThan(defaultResult.confidence, 0.8)
    }
}
