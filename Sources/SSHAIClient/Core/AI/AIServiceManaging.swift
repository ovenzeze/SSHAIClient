import Foundation

// MARK: - Core AI Service Protocol

/// Protocol defining the interface for AI service providers
public protocol AIServiceManaging: Sendable {
    /// Service identification
    var name: String { get }
    var version: String { get }
    var provider: AIProvider { get }
    
    /// Core AI capabilities
    func generateCommand(_ query: String, context: GenerationContext) async throws -> CommandSuggestion
    func classifyIntent(_ input: String, context: TerminalContext?) async throws -> IntentResult
    
    /// Service management
    func isAvailable() async -> Bool
    func testConnection() async throws -> Bool
    func getRateLimit() async -> RateLimit?
    
    /// Configuration
    func configure(with config: AIServiceConfig) async throws
    func supportedLanguages() -> [String]
}

// MARK: - AI Provider Enumeration

/// AI Provider enumeration defining supported AI service providers
public enum AIProvider: String, CaseIterable, Sendable {
    case groq = "groq"          // Groq: High-performance inference platform with free tier
    case openai = "openai"      // OpenAI: GPT models, premium quality, paid service
    case claude = "claude"      // Anthropic Claude: Advanced reasoning, moderate pricing
    case ollama = "ollama"
    case custom = "custom"
    
    public var displayName: String {
        switch self {
        case .groq: return "Groq"
        case .openai: return "OpenAI"
        case .claude: return "Anthropic Claude"
        case .ollama: return "Ollama"
        case .custom: return "Custom Provider"
        }
    }
    
    public var baseURL: String {
        switch self {
        case .groq: return "https://api.groq.com/openai/v1"
        case .openai: return "https://api.openai.com/v1"
        case .claude: return "https://api.anthropic.com"
        case .ollama: return "http://localhost:11434/v1"
        case .custom: return "" // Should be configured by user
        }
    }
    
    public var defaultModel: String {
        switch self {
        case .groq: return "llama3-70b-8192"
        case .openai: return "gpt-4"
        case .claude: return "claude-3-sonnet-20240229"
        case .ollama: return "llama2"
        case .custom: return "gpt-3.5-turbo"
        }
    }
}

// MARK: - Configuration Structures

public struct AIServiceConfig: Sendable {
    public let provider: AIProvider
    public let baseURL: String?
    public let model: String?
    public let maxTokens: Int
    public let temperature: Double
    public let timeout: TimeInterval
    public let maxRetries: Int
    
    public init(
        provider: AIProvider = .groq,
        baseURL: String? = nil,
        model: String? = nil,
        maxTokens: Int = 1000,
        temperature: Double = 0.1,
        timeout: TimeInterval = 30.0,
        maxRetries: Int = 3
    ) {
        self.provider = provider
        self.baseURL = baseURL ?? provider.baseURL
        self.model = model ?? provider.defaultModel
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.timeout = timeout
        self.maxRetries = maxRetries
    }
}

public struct RateLimit: Sendable {
    public let requestsPerMinute: Int
    public let requestsRemaining: Int
    public let resetTime: Date
    
    public init(requestsPerMinute: Int, requestsRemaining: Int, resetTime: Date) {
        self.requestsPerMinute = requestsPerMinute
        self.requestsRemaining = requestsRemaining
        self.resetTime = resetTime
    }
}

// MARK: - Terminal Context (for Intent Classification)

public struct TerminalContext: Sendable {
    public let workingDirectory: String?
    public let recentCommands: [String]
    public let shell: String?
    public let environment: [String: String]
    
    public init(
        workingDirectory: String? = nil,
        recentCommands: [String] = [],
        shell: String? = nil,
        environment: [String: String] = [:]
    ) {
        self.workingDirectory = workingDirectory
        self.recentCommands = recentCommands
        self.shell = shell
        self.environment = environment
    }
}

// MARK: - Intent Classification Results

public enum IntentType: Sendable {
    case command      // Direct shell command execution
    case aiQuery      // Natural language query requiring AI processing
    case ambiguous    // Unclear intent, needs clarification
}

public struct IntentResult: Sendable {
    public let type: IntentType
    public let confidence: Double
    public let explanation: String
    
    public init(type: IntentType, confidence: Double, explanation: String) {
        self.type = type
        self.confidence = confidence
        self.explanation = explanation
    }
}

// MARK: - AI Service Errors

public enum AIServiceError: Error, LocalizedError {
    case configurationInvalid(String)
    case authenticationFailed(String)
    case networkTimeout
    case rateLimitExceeded(resetTime: Date?)
    case serviceUnavailable(String?)
    case invalidResponse(String)
    case modelNotFound(String)
    case quotaExceeded
    case apiKeyMissing
    case requestTooLarge(maxTokens: Int)
    
    public var errorDescription: String? {
        switch self {
        case .configurationInvalid(let details):
            return "AI service configuration is invalid: \(details)"
        case .authenticationFailed(let details):
            return "Authentication failed: \(details)"
        case .networkTimeout:
            return "Network request timed out"
        case .rateLimitExceeded(let resetTime):
            if let resetTime = resetTime {
                return "Rate limit exceeded. Try again after \(resetTime)"
            } else {
                return "Rate limit exceeded"
            }
        case .serviceUnavailable(let details):
            return "AI service unavailable: \(details ?? "Unknown error")"
        case .invalidResponse(let details):
            return "Invalid response from AI service: \(details)"
        case .modelNotFound(let model):
            return "Model not found: \(model)"
        case .quotaExceeded:
            return "API quota exceeded"
        case .apiKeyMissing:
            return "API key is missing or invalid"
        case .requestTooLarge(let maxTokens):
            return "Request too large. Maximum tokens allowed: \(maxTokens)"
        }
    }
}

// MARK: - Default Protocol Implementations

public extension AIServiceManaging {
    /// Default rate limit implementation (no limits)
    func getRateLimit() async -> RateLimit? {
        return nil
    }
    
    /// Default language support (English only)
    func supportedLanguages() -> [String] {
        return ["en", "en-US", "en-GB"]
    }
    
    /// Default availability check
    func isAvailable() async -> Bool {
        do {
            return try await testConnection()
        } catch {
            return false
        }
    }
}
