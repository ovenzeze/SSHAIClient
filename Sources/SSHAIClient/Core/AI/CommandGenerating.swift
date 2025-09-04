import Foundation

// MARK: - Public Data Structures

/// Host system information for command generation context
public struct HostInfo: Equatable, Sendable {
    public let osName: String
    public let osVersion: String
    public let architecture: String
    
    public init(osName: String, osVersion: String, architecture: String) {
        self.osName = osName
        self.osVersion = osVersion
        self.architecture = architecture
    }
}

/// Shell information for command generation context
public struct ShellInfo: Equatable, Sendable {
    public let name: String // zsh, bash, fish
    public let version: String?
    
    public init(name: String, version: String? = nil) {
        self.name = name
        self.version = version
    }
}

/// User preferences for command generation
public struct UserPreferences: Equatable, Sendable {
    public let preferSafeFlags: Bool
    public let preferOneLiners: Bool
    public let language: String // e.g., "en-US"
    
    public init(preferSafeFlags: Bool = true, preferOneLiners: Bool = false, language: String = "en-US") {
        self.preferSafeFlags = preferSafeFlags
        self.preferOneLiners = preferOneLiners
        self.language = language
    }
}

/// Complete context for command generation
public struct GenerationContext: Equatable, Sendable {
    public let host: HostInfo
    public let shell: ShellInfo
    public let workingDirectory: String
    public let recentCommands: [String]
    public let environment: [String: String]
    public let userPreferences: UserPreferences
    
    public init(
        host: HostInfo,
        shell: ShellInfo,
        workingDirectory: String,
        recentCommands: [String] = [],
        environment: [String: String] = [:],
        userPreferences: UserPreferences = UserPreferences()
    ) {
        self.host = host
        self.shell = shell
        self.workingDirectory = workingDirectory
        self.recentCommands = recentCommands
        self.environment = environment
        self.userPreferences = userPreferences
    }
}

/// Risk level assessment for generated commands
public enum RiskLevel: String, CaseIterable, Sendable {
    case safe
    case caution
    case dangerous
    
    /// Human-readable description of the risk level
    public var description: String {
        switch self {
        case .safe:
            return "Safe to execute"
        case .caution:
            return "Review before executing"
        case .dangerous:
            return "Potentially destructive - use with extreme caution"
        }
    }
}

/// Generated command suggestion with metadata
public struct CommandSuggestion: Equatable, Sendable {
    public let command: String
    public let explanation: String
    public let risk: RiskLevel
    public let confidence: Double // 0.0 to 1.0
    
    public init(command: String, explanation: String, risk: RiskLevel, confidence: Double) {
        self.command = command
        self.explanation = explanation
        self.risk = risk
        self.confidence = max(0.0, min(1.0, confidence)) // Clamp to valid range
    }
}

/// Errors that can occur during command generation
public enum CommandGenerationError: Error, Equatable {
    case invalidQuery(String)
    case contextInsufficient(String)
    case generationFailed(underlying: String?)
    case unsupportedLanguage(String)
    case rateLimitExceeded
    
    public var localizedDescription: String {
        switch self {
        case .invalidQuery(let query):
            return "Invalid query: \(query)"
        case .contextInsufficient(let reason):
            return "Insufficient context: \(reason)"
        case .generationFailed(let underlying):
            return "Generation failed: \(underlying ?? "Unknown error")"
        case .unsupportedLanguage(let language):
            return "Unsupported language: \(language)"
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        }
    }
}

// MARK: - Protocol Definition

/// An interface for generating shell commands from natural language queries.
/// This protocol abstracts the underlying AI implementation, allowing for
/// different providers (local AI, remote API, rule-based systems, etc.).
public protocol CommandGenerating: Sendable {
    /// Generate a shell command suggestion based on a natural language query and context.
    /// - Parameters:
    ///   - query: User's natural language instruction
    ///   - context: Execution context to guide generation for correctness and safety
    /// - Returns: CommandSuggestion with command, explanation, risk level and confidence
    /// - Throws: CommandGenerationError for various failure scenarios
    func generate(query: String, context: GenerationContext) async throws -> CommandSuggestion
    
    /// Check if the generator supports the given language
    /// - Parameter language: Language code (e.g., "en-US", "zh-CN")
    /// - Returns: True if the language is supported
    func supportsLanguage(_ language: String) -> Bool
    
    /// Get the current rate limit status (optional, for implementations that have rate limits)
    /// - Returns: Remaining requests and reset time, or nil if not applicable
    func getRateLimitStatus() async -> (remaining: Int, resetTime: Date)?
}

// MARK: - Default Protocol Extensions

public extension CommandGenerating {
    /// Default implementation for rate limit status (no limits)
    func getRateLimitStatus() async -> (remaining: Int, resetTime: Date)? {
        return nil
    }
    
    /// Default implementation for language support (English only)
    func supportsLanguage(_ language: String) -> Bool {
        return language.hasPrefix("en")
    }
}
