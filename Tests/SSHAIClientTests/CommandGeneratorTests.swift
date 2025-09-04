import XCTest
@testable import SSHAIClient

/// Comprehensive test suite for CommandGenerator functionality.
/// This serves as a testing template and best practices guide for the project.
final class CommandGeneratorTests: XCTestCase {
    
    // MARK: - Test Infrastructure
    
    var generator: CommandGenerator!
    var mockGenerator: MockCommandGenerator!
    var testContext: GenerationContext!
    
    override func setUp() {
        super.setUp()
        
        // Initialize real implementation
        generator = CommandGenerator()
        
        // Initialize mock for controlled testing
        mockGenerator = MockCommandGenerator()
        
        // Create standard test context
        testContext = createTestContext()
    }
    
    override func tearDown() {
        generator = nil
        mockGenerator = nil
        testContext = nil
        super.tearDown()
    }
    
    // MARK: - Happy Path Tests
    
    @MainActor
    func testGenerate_ListFilesQuery_ReturnsLsCommand() async throws {
        // Arrange
        let query = "list files and directories"
        
        // Act
        let result = try await generator.generate(query: query, context: testContext)
        
        // Assert
        XCTAssertEqual(result.command, "ls -la")
        XCTAssertEqual(result.risk, .safe)
        XCTAssertGreaterThan(result.confidence, 0.8)
        XCTAssertFalse(result.explanation.isEmpty)
        XCTAssertTrue(result.explanation.contains("Lists"))
    }
    
    @MainActor
    func testGenerate_ChangeDirectoryToHome_ReturnsCdHomeCommand() async throws {
        // Arrange
        let query = "go to home directory"
        
        // Act
        let result = try await generator.generate(query: query, context: testContext)
        
        // Assert
        XCTAssertEqual(result.command, "cd ~")
        XCTAssertEqual(result.risk, .safe)
        XCTAssertGreaterThan(result.confidence, 0.9)
        XCTAssertTrue(result.explanation.contains("home"))
    }
    
    @MainActor
    func testGenerate_SystemInfoOnMacOS_ReturnsSwVers() async throws {
        // Arrange
        let query = "show system info"
        let macContext = createTestContext(osName: "Darwin")
        
        // Act
        let result = try await generator.generate(query: query, context: macContext)
        
        // Assert
        XCTAssertEqual(result.command, "sw_vers")
        XCTAssertEqual(result.risk, .safe)
        XCTAssertTrue(result.explanation.contains("system information"))
    }
    
    @MainActor
    func testGenerate_SystemInfoOnLinux_ReturnsUname() async throws {
        // Arrange
        let query = "os version"
        let linuxContext = createTestContext(osName: "Linux")
        
        // Act
        let result = try await generator.generate(query: query, context: linuxContext)
        
        // Assert
        XCTAssertEqual(result.command, "uname -a")
        XCTAssertEqual(result.risk, .safe)
    }
    
    // MARK: - Error Handling Tests
    
    func testGenerate_EmptyQuery_ThrowsInvalidQueryError() async {
        // Arrange
        let emptyQuery = "   "
        
        // Act & Assert
        await XCTAssertThrowsError(
            try await generator.generate(query: emptyQuery, context: testContext)
        ) { error in
            guard case CommandGenerationError.invalidQuery = error else {
                XCTFail("Expected invalidQuery error, got \(error)")
                return
            }
        }
    }
    
    func testGenerate_UnsupportedLanguage_ThrowsUnsupportedLanguageError() async {
        // Arrange
        let query = "list files"
        let chineseContext = createTestContext(language: "zh-CN")
        
        // Act & Assert
        await XCTAssertThrowsError(
            try await generator.generate(query: query, context: chineseContext)
        ) { error in
            guard case CommandGenerationError.unsupportedLanguage(let language) = error else {
                XCTFail("Expected unsupportedLanguage error, got \(error)")
                return
            }
            XCTAssertEqual(language, "zh-CN")
        }
    }
    
    // MARK: - Risk Assessment Tests
    
    @MainActor
    func testGenerate_DangerousDeleteAllQuery_ReturnsDangerousRisk() async throws {
        // Arrange
        let query = "delete all files"
        
        // Act
        let result = try await generator.generate(query: query, context: testContext)
        
        // Assert
        XCTAssertEqual(result.risk, .dangerous)
        XCTAssertGreaterThan(result.confidence, 0.8)
        XCTAssertTrue(result.command.contains("DANGEROUS"))
        XCTAssertTrue(result.explanation.contains("destructive"))
    }
    
    @MainActor
    func testGenerate_CautiousDeleteQuery_ReturnsCautionRisk() async throws {
        // Arrange
        let query = "remove file"
        
        // Act
        let result = try await generator.generate(query: query, context: testContext)
        
        // Assert
        XCTAssertEqual(result.risk, .caution)
        XCTAssertTrue(result.command.contains("rm"))
        XCTAssertTrue(result.explanation.contains("Replace"))
    }
    
    // MARK: - Language Support Tests
    
    func testSupportsLanguage_EnglishVariants_ReturnsTrue() {
        // Test various English language codes
        let englishCodes = ["en", "en-US", "en-GB", "en-AU"]
        
        for code in englishCodes {
            XCTAssertTrue(
                generator.supportsLanguage(code),
                "Should support language code: \(code)"
            )
        }
    }
    
    func testSupportsLanguage_NonEnglish_ReturnsFalse() {
        // Test non-English language codes
        let nonEnglishCodes = ["zh-CN", "es-ES", "fr-FR", "de-DE"]
        
        for code in nonEnglishCodes {
            XCTAssertFalse(
                generator.supportsLanguage(code),
                "Should not support language code: \(code)"
            )
        }
    }
    
    // MARK: - Performance Tests
    
    func testGenerate_Performance_CompletesWithinReasonableTime() async throws {
        // Arrange
        let query = "list files"
        let startTime = Date()
        
        // Act
        _ = try await generator.generate(query: query, context: testContext)
        
        // Assert
        let duration = Date().timeIntervalSince(startTime)
        XCTAssertLessThan(duration, 1.0, "Generation should complete within 1 second")
    }
    
    // MARK: - Mock-based Tests (demonstrating testing with mocks)
    
    func testGenerate_WithMock_ReturnsExpectedResult() async throws {
        // Arrange
        let query = "test query"
        let expectedSuggestion = CommandSuggestion(
            command: "mock command",
            explanation: "mock explanation",
            risk: .safe,
            confidence: 1.0
        )
        mockGenerator.stubGenerate(result: expectedSuggestion)
        
        // Act
        let result = try await mockGenerator.generate(query: query, context: testContext)
        
        // Assert
        XCTAssertEqual(result, expectedSuggestion)
        XCTAssertEqual(mockGenerator.generateCallCount, 1)
        XCTAssertEqual(mockGenerator.lastQuery, query)
    }
    
    func testGenerate_WithMockError_ThrowsExpectedError() async {
        // Arrange
        let query = "test query"
        let expectedError = CommandGenerationError.rateLimitExceeded
        mockGenerator.stubGenerate(error: expectedError)
        
        // Act & Assert
        await XCTAssertThrowsError(
            try await mockGenerator.generate(query: query, context: testContext)
        ) { error in
            XCTAssertEqual(error as? CommandGenerationError, expectedError)
        }
    }
    
    // MARK: - Integration Tests
    
    func testGenerate_MultipleQueries_MaintainsConsistency() async throws {
        // Test that the same query produces consistent results
        let query = "list files"
        
        let result1 = try await generator.generate(query: query, context: testContext)
        let result2 = try await generator.generate(query: query, context: testContext)
        
        XCTAssertEqual(result1.command, result2.command)
        XCTAssertEqual(result1.risk, result2.risk)
    }
    
    // MARK: - Edge Case Tests
    
    @MainActor
    func testGenerate_UnknownQuery_ReturnsLowConfidenceResult() async throws {
        // Arrange
        let unknownQuery = "xyzabc123 unknown command"
        
        // Act
        let result = try await generator.generate(query: unknownQuery, context: testContext)
        
        // Assert
        XCTAssertLessThan(result.confidence, 0.5)
        XCTAssertEqual(result.risk, .safe)
        XCTAssertTrue(result.command.contains("Unable to generate"))
    }
    
    // MARK: - Test Helpers
    
    private func createTestContext(
        osName: String = "Darwin",
        language: String = "en-US"
    ) -> GenerationContext {
        let host = HostInfo(
            osName: osName,
            osVersion: "14.0",
            architecture: "arm64"
        )
        
        let shell = ShellInfo(
            name: "zsh",
            version: "5.8"
        )
        
        let preferences = UserPreferences(
            preferSafeFlags: true,
            preferOneLiners: false,
            language: language
        )
        
        return GenerationContext(
            host: host,
            shell: shell,
            workingDirectory: "/Users/test",
            recentCommands: ["pwd", "ls"],
            environment: ["PATH": "/usr/bin:/bin"],
            userPreferences: preferences
        )
    }
}

// MARK: - Mock Implementation

/// Mock implementation of CommandGenerating for testing purposes.
/// This demonstrates how to create testable mocks for protocols.
class MockCommandGenerator: CommandGenerating, @unchecked Sendable {
    
    // MARK: - Call Tracking
    
    private(set) var generateCallCount = 0
    private(set) var lastQuery: String?
    private(set) var lastContext: GenerationContext?
    
    // MARK: - Stubbing
    
    private var stubbedResult: CommandSuggestion?
    private var stubbedError: Error?
    private var stubbedLanguageSupport: [String: Bool] = [:]
    private var stubbedRateLimit: (remaining: Int, resetTime: Date)?
    
    func stubGenerate(result: CommandSuggestion) {
        stubbedResult = result
        stubbedError = nil
    }
    
    func stubGenerate(error: Error) {
        stubbedError = error
        stubbedResult = nil
    }
    
    func stubLanguageSupport(_ language: String, supported: Bool) {
        stubbedLanguageSupport[language] = supported
    }
    
    func stubRateLimit(remaining: Int, resetTime: Date) {
        stubbedRateLimit = (remaining, resetTime)
    }
    
    // MARK: - Protocol Implementation
    
    func generate(query: String, context: GenerationContext) async throws -> CommandSuggestion {
        generateCallCount += 1
        lastQuery = query
        lastContext = context
        
        if let error = stubbedError {
            throw error
        }
        
        return stubbedResult ?? CommandSuggestion(
            command: "default mock command",
            explanation: "default mock explanation",
            risk: .safe,
            confidence: 0.5
        )
    }
    
    func supportsLanguage(_ language: String) -> Bool {
        return stubbedLanguageSupport[language] ?? language.hasPrefix("en")
    }
    
    func getRateLimitStatus() async -> (remaining: Int, resetTime: Date)? {
        return stubbedRateLimit
    }
}

// MARK: - XCTest Extensions

extension XCTAssertThrowsError {
    /// Async version of XCTAssertThrowsError for testing async throwing functions
    static func XCTAssertThrowsError<T>(
        _ expression: @autoclosure () async throws -> T,
        _ message: @autoclosure () -> String = "",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ errorHandler: (_ error: Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error to be thrown", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }
}
