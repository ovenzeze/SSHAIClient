import Foundation

/// Universal OpenAI-compatible API client for various AI providers
public final class OpenAICompatibleClient: AIServiceManaging, @unchecked Sendable {
    
    // MARK: - Properties
    
    public let name: String
    public let version: String = "1.0.0"
    public let provider: AIProvider
    
    private let config: AIServiceConfig
    private let onePasswordManager: OnePasswordManaging
    private let urlSession: URLSession
    private var cachedAPIKey: String?
    private var lastRateLimit: RateLimit?
    
    // MARK: - Initialization
    
    public init(
        config: AIServiceConfig = AIServiceConfig(),
        onePasswordManager: OnePasswordManaging = OnePasswordManager()
    ) {
        self.config = config
        self.provider = config.provider
        self.name = "\(config.provider.displayName) Client"
        self.onePasswordManager = onePasswordManager
        
        // Configure URLSession with timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout * 2
        self.urlSession = URLSession(configuration: configuration)
    }
    
    // MARK: - AIServiceManaging Implementation
    
    public func generateCommand(_ query: String, context: GenerationContext) async throws -> CommandSuggestion {
        let prompt = buildCommandGenerationPrompt(query: query, context: context)
        let response = try await sendChatRequest(messages: prompt)
        return try parseCommandResponse(response)
    }
    
    public func classifyIntent(_ input: String, context: TerminalContext?) async throws -> IntentResult {
        let prompt = buildIntentClassificationPrompt(input: input, context: context)
        let response = try await sendChatRequest(messages: prompt)
        return try parseIntentResponse(response)
    }
    
    public func testConnection() async throws -> Bool {
        let testMessages = [
            ChatMessage(role: .user, content: "Hello, are you working?")
        ]
        
        do {
            _ = try await sendChatRequest(messages: testMessages)
            return true
        } catch AIServiceError.authenticationFailed {
            throw AIServiceError.authenticationFailed("API key is invalid or expired")
        } catch {
            throw AIServiceError.serviceUnavailable("Connection test failed: \(error.localizedDescription)")
        }
    }
    
    public func configure(with config: AIServiceConfig) async throws {
        // This implementation is immutable, so we'd need to create a new instance
        // For now, we'll validate the configuration
        guard let baseURL = config.baseURL, !baseURL.isEmpty else {
            throw AIServiceError.configurationInvalid("Base URL cannot be empty")
        }
        
        guard config.maxTokens > 0 else {
            throw AIServiceError.configurationInvalid("Max tokens must be greater than 0")
        }
    }
    
    public func getRateLimit() async -> RateLimit? {
        return lastRateLimit
    }
    
    public func supportedLanguages() -> [String] {
        return ["en", "en-US", "en-GB", "zh-CN", "es-ES", "fr-FR", "de-DE"]
    }
    
    // MARK: - Private API Methods
    
    private func getAPIKey() async throws -> String {
        if let cachedKey = cachedAPIKey {
            return cachedKey
        }
        
        let apiKey = try await onePasswordManager.getAPIKeyWithFallback(for: provider)
        cachedAPIKey = apiKey
        return apiKey
    }
    
    private func sendChatRequest(messages: [ChatMessage]) async throws -> ChatResponse {
        let apiKey = try await getAPIKey()
        
        let request = ChatRequest(
            model: config.model ?? provider.defaultModel,
            messages: messages,
            temperature: config.temperature,
            maxTokens: config.maxTokens
        )
        
        let baseURL = config.baseURL ?? provider.baseURL
        var urlRequest = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("SSHAIClient/1.0", forHTTPHeaderField: "User-Agent")
        
        // Special handling for different providers
        switch provider {
        case .claude:
            // Anthropic uses a different header format
            urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .groq:
            // Groq is fully OpenAI compatible, no special handling needed
            break
        case .openai:
            // Standard OpenAI format
            break
        case .ollama:
            // Ollama typically doesn't require API key for local instances
            urlRequest.setValue("application/json", forHTTPHeaderField: "Authorization")
        case .custom:
            // Use standard OpenAI format for custom providers
            break
        }
        
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw AIServiceError.invalidResponse("Failed to encode request: \(error)")
        }
        
        // Perform request with retry logic
        return try await performRequestWithRetry(urlRequest)
    }
    
    private func performRequestWithRetry(_ request: URLRequest) async throws -> ChatResponse {
        var lastError: Error?
        
        for attempt in 1...config.maxRetries {
            do {
                let (data, response) = try await urlSession.data(for: request)
                
                // Handle HTTP response
                if let httpResponse = response as? HTTPURLResponse {
                    try handleHTTPResponse(httpResponse, data: data)
                }
                
                // Parse successful response
                return try JSONDecoder().decode(ChatResponse.self, from: data)
                
            } catch {
                lastError = error
                
                // Don't retry for certain errors
                if case AIServiceError.authenticationFailed = error,
                   case AIServiceError.quotaExceeded = error {
                    throw error
                }
                
                // Wait before retry (exponential backoff)
                if attempt < config.maxRetries {
                    let delay = Double(attempt) * 1.0
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? AIServiceError.serviceUnavailable("All retry attempts failed")
    }
    
    private func handleHTTPResponse(_ response: HTTPURLResponse, data: Data) throws {
        // Extract rate limit information
        if let remaining = response.value(forHTTPHeaderField: "x-ratelimit-remaining-requests"),
           let resetTime = response.value(forHTTPHeaderField: "x-ratelimit-reset-requests") {
            if let remainingInt = Int(remaining),
               let resetDouble = Double(resetTime) {
                let resetDate = Date(timeIntervalSince1970: resetDouble)
                lastRateLimit = RateLimit(
                    requestsPerMinute: 60, // Default assumption
                    requestsRemaining: remainingInt,
                    resetTime: resetDate
                )
            }
        }
        
        switch response.statusCode {
        case 200...299:
            // Success
            return
        case 401:
            throw AIServiceError.authenticationFailed("Invalid API key")
        case 429:
            let resetTime = lastRateLimit?.resetTime
            throw AIServiceError.rateLimitExceeded(resetTime: resetTime)
        case 402:
            throw AIServiceError.quotaExceeded
        case 404:
            throw AIServiceError.modelNotFound(config.model ?? "unknown")
        case 413:
            throw AIServiceError.requestTooLarge(maxTokens: config.maxTokens)
        case 500...599:
            let errorMessage = String(data: data, encoding: .utf8) ?? "Server error"
            throw AIServiceError.serviceUnavailable(errorMessage)
        default:
            let errorMessage = "HTTP \(response.statusCode): \(String(data: data, encoding: .utf8) ?? "Unknown error")"
            throw AIServiceError.invalidResponse(errorMessage)
        }
    }
}

// MARK: - Prompt Building Methods

extension OpenAICompatibleClient {
    
    private func buildCommandGenerationPrompt(query: String, context: GenerationContext) -> [ChatMessage] {
        let systemPrompt = """
        You are an expert system administrator and command-line assistant. Your job is to convert natural language queries into safe, accurate shell commands.
        
        CONTEXT:
        - Operating System: \(context.host.osName) \(context.host.osVersion)
        - Shell: \(context.shell.name) \(context.shell.version ?? "")
        - Architecture: \(context.host.architecture)
        - Working Directory: \(context.workingDirectory)
        - Recent Commands: \(context.recentCommands.joined(separator: ", "))
        
        RESPONSE FORMAT:
        Respond with a JSON object containing:
        {
            "command": "the exact shell command",
            "explanation": "brief explanation of what the command does",
            "risk": "safe|caution|dangerous",
            "confidence": 0.95
        }
        
        SAFETY RULES:
        1. Never generate commands that could delete important system files
        2. Warn about destructive operations (rm, dd, format, etc.)
        3. Prefer safe flags (e.g., rm -i instead of rm -f)
        4. If query is ambiguous, ask for clarification
        5. Mark risky commands with appropriate risk level
        
        Generate ONE command that best matches the user's intent.
        """
        
        return [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: query)
        ]
    }
    
    private func buildIntentClassificationPrompt(input: String, context: TerminalContext?) -> [ChatMessage] {
        let contextInfo = context.map { ctx in
            "Working Directory: \(ctx.workingDirectory ?? "unknown"), Recent: \(ctx.recentCommands.joined(separator: ", "))"
        } ?? "No context available"
        
        let systemPrompt = """
        You are an intent classifier for terminal input. Classify user input as either:
        - "command": Direct shell command that can be executed as-is
        - "aiQuery": Natural language query that needs AI processing to generate a command
        - "ambiguous": Unclear intent that needs clarification
        
        CONTEXT: \(contextInfo)
        
        RESPONSE FORMAT:
        Respond with a JSON object:
        {
            "type": "command|aiQuery|ambiguous",
            "confidence": 0.95,
            "explanation": "brief reason for classification"
        }
        
        CLASSIFICATION RULES:
        - Commands start with unix commands (ls, cd, git, docker, etc.)
        - Commands contain shell syntax (pipes, redirects, flags)
        - Natural language contains question words (how, what, show me, etc.)
        - Natural language describes desired outcomes rather than specific commands
        """
        
        return [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: input)
        ]
    }
}

// MARK: - Response Parsing Methods

extension OpenAICompatibleClient {
    
    private func parseCommandResponse(_ response: ChatResponse) throws -> CommandSuggestion {
        guard let content = response.choices.first?.message.content else {
            throw AIServiceError.invalidResponse("No content in response")
        }
        
        // Try to parse JSON response
        guard let jsonData = content.data(using: .utf8) else {
            throw AIServiceError.invalidResponse("Could not encode response as UTF-8")
        }
        
        struct AICommandResponse: Codable {
            let command: String
            let explanation: String
            let risk: String
            let confidence: Double
        }
        
        do {
            let aiResponse = try JSONDecoder().decode(AICommandResponse.self, from: jsonData)
            
            let riskLevel: RiskLevel = switch aiResponse.risk.lowercased() {
            case "safe": .safe
            case "caution": .caution
            case "dangerous": .dangerous
            default: .caution
            }
            
            return CommandSuggestion(
                command: aiResponse.command,
                explanation: aiResponse.explanation,
                risk: riskLevel,
                confidence: max(0.0, min(1.0, aiResponse.confidence))
            )
        } catch {
            // Fallback: try to extract command from plain text
            return parseCommandFromPlainText(content)
        }
    }
    
    private func parseIntentResponse(_ response: ChatResponse) throws -> IntentResult {
        guard let content = response.choices.first?.message.content else {
            throw AIServiceError.invalidResponse("No content in response")
        }
        
        guard let jsonData = content.data(using: .utf8) else {
            throw AIServiceError.invalidResponse("Could not encode response as UTF-8")
        }
        
        struct AIIntentResponse: Codable {
            let type: String
            let confidence: Double
            let explanation: String
        }
        
        do {
            let aiResponse = try JSONDecoder().decode(AIIntentResponse.self, from: jsonData)
            
            let intentType: IntentType = switch aiResponse.type.lowercased() {
            case "command": .command
            case "aiquery": .aiQuery
            case "ambiguous": .ambiguous
            default: .ambiguous
            }
            
            return IntentResult(
                type: intentType,
                confidence: max(0.0, min(1.0, aiResponse.confidence)),
                explanation: aiResponse.explanation
            )
        } catch {
            // Fallback to basic classification
            return IntentResult(
                type: .aiQuery,
                confidence: 0.5,
                explanation: "Failed to parse AI response, defaulting to AI query"
            )
        }
    }
    
    private func parseCommandFromPlainText(_ content: String) -> CommandSuggestion {
        // Simple extraction of command from plain text (fallback)
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.starts(with: "$") || trimmed.starts(with: "# ") {
                continue
            }
            
            // Look for typical command patterns
            let commonCommands = ["ls", "cd", "git", "docker", "kubectl", "npm", "yarn", "pip", "grep", "find", "cat", "tail", "head"]
            
            if commonCommands.contains(where: { trimmed.starts(with: $0 + " ") || trimmed == $0 }) {
                return CommandSuggestion(
                    command: trimmed,
                    explanation: "Command extracted from AI response",
                    risk: .caution,
                    confidence: 0.6
                )
            }
        }
        
        return CommandSuggestion(
            command: "# Could not parse command from AI response",
            explanation: "AI response could not be parsed into a valid command",
            risk: .safe,
            confidence: 0.1
        )
    }
}

// MARK: - Data Structures

public struct ChatRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

public struct ChatMessage: Codable {
    let role: Role
    let content: String
    
    public enum Role: String, Codable {
        case system = "system"
        case user = "user"
        case assistant = "assistant"
    }
    
    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

public struct ChatResponse: Codable {
    let id: String
    let object: String
    let created: Int
    let model: String
    let choices: [Choice]
    let usage: Usage?
    
    public struct Choice: Codable {
        let index: Int
        let message: ChatMessage
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case index
            case message
            case finishReason = "finish_reason"
        }
    }
    
    public struct Usage: Codable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
        }
    }
}
