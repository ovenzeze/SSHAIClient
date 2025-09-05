import Foundation

/// AI Client that uses the unified JSON schema for structured responses
public final class UnifiedAIClient: Sendable {
    
    private let config: AIServiceConfig
    private let apiKey: String
    private let urlSession: URLSession
    
    public init(config: AIServiceConfig, apiKey: String) {
        self.config = config
        self.apiKey = apiKey
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout * 2
        self.urlSession = URLSession(configuration: configuration)
    }
    
    /// Generate command using unified schema
    public func generateCommand(_ request: AICommandRequest) async throws -> AICommandResponse {
        // Build the prompt that instructs the model to return structured JSON
        let systemPrompt = buildStructuredPrompt(for: request)
        
        // Create the API request
        let apiRequest = UnifiedChatCompletionRequest(
            model: config.model ?? config.provider.defaultModel,
            messages: [
                UnifiedChatMessage(role: .system, content: systemPrompt),
                UnifiedChatMessage(role: .user, content: request.input.content)
            ],
            temperature: request.options.temperature ?? config.temperature,
            maxTokens: request.options.maxTokens ?? config.maxTokens,
            responseFormat: UnifiedResponseFormat(type: "json_object")
        )
        
        // Make the API call
        let startTime = Date()
        let chatResponse = try await performAPICall(apiRequest)
        let processingTime = Date().timeIntervalSince(startTime)
        
        // Parse the structured response
        guard let content = chatResponse.choices.first?.message.content else {
            throw AIServiceError.invalidResponse("No content in response")
        }
        
        // Try to parse as our unified response format
        if let response = try? parseStructuredResponse(
            content,
            requestId: request.requestId,
            processingTime: processingTime,
            usage: chatResponse.usage
        ) {
            return response
        }
        
        // Fallback: create a basic response
        return createFallbackResponse(
            from: content,
            requestId: request.requestId,
            processingTime: processingTime
        )
    }
    
    // MARK: - Private Methods
    
    private func buildStructuredPrompt(for request: AICommandRequest) -> String {
        """
        You are an advanced command generation AI. Analyze the user's request and generate appropriate shell commands.
        
        CONTEXT INFORMATION:
        - System: \(request.context.system.os) \(request.context.system.osVersion) on \(request.context.system.architecture)
        - Shell: \(request.context.terminal.shell) \(request.context.terminal.shellVersion ?? "")
        - Working Directory: \(request.context.terminal.workingDirectory)
        - User Permissions: \(request.context.user.permissions?.rawValue ?? "unknown")
        - Safe Mode: \(request.context.user.preferences?.preferSafeMode ?? true)
        - Recent Commands: \(request.context.history?.recentCommands.joined(separator: ", ") ?? "none")
        
        REQUIREMENTS:
        1. Generate safe, accurate shell commands for the user's request
        2. Assess risk level carefully (safe, low, medium, high, critical)
        3. Provide alternatives when appropriate
        4. Include step-by-step explanations
        5. Return ONLY valid JSON matching this exact structure:
        
        {
          "result": {
            "status": "success|partial|error|needs_clarification",
            "commands": [
              {
                "id": "unique-id",
                "content": "the actual command",
                "type": "shell|script|pipeline|function",
                "risk": {
                  "level": "safe|low|medium|high|critical",
                  "score": 0.0-1.0,
                  "factors": ["list of risk factors"],
                  "warnings": ["optional warnings"],
                  "requiresConfirmation": true/false
                },
                "alternatives": [
                  {
                    "command": "alternative command",
                    "description": "why use this",
                    "tradeoffs": "pros and cons"
                  }
                ],
                "dependencies": ["required", "tools"],
                "platforms": ["Darwin", "Linux"]
              }
            ],
            "explanation": {
              "summary": "brief summary",
              "details": "detailed explanation",
              "steps": [
                {
                  "order": 1,
                  "description": "what this step does",
                  "command": "command fragment",
                  "note": "additional info"
                }
              ],
              "references": ["man pages", "URLs"]
            },
            "error": {
              "code": "ERROR_CODE",
              "message": "error description",
              "type": "invalid_input|unsupported|ambiguous|dangerous|system_error",
              "suggestions": ["how to fix"]
            }
          },
          "metadata": {
            "model": "\(config.model ?? config.provider.defaultModel)",
            "provider": "\(config.provider.rawValue)",
            "confidence": 0.0-1.0,
            "tags": ["relevant", "tags"]
          }
        }
        
        IMPORTANT RULES:
        - If the request is dangerous and safe mode is enabled, return an error
        - Always validate commands for the target OS (\(request.context.system.os))
        - Include warnings for operations that modify or delete data
        - Prefer read-only operations when the intent is ambiguous
        - Return valid, parseable JSON only
        """
    }
    
    private func parseStructuredResponse(
        _ jsonContent: String,
        requestId: String,
        processingTime: TimeInterval,
        usage: UnifiedChatResponse.Usage?
    ) throws -> AICommandResponse {
        guard let data = jsonContent.data(using: .utf8) else {
            throw AIServiceError.invalidResponse("Invalid UTF-8 content")
        }
        
        let decoder = JSONDecoder()
        
        // Try to decode the partial response from AI
        let partialResponse = try decoder.decode(PartialAIResponse.self, from: data)
        
        // Convert to full response
        return AICommandResponse(
            requestId: requestId,
            timestamp: Date(),
            result: partialResponse.result,
            metadata: AICommandResponse.Metadata(
                model: partialResponse.metadata.model,
                provider: partialResponse.metadata.provider,
                confidence: partialResponse.metadata.confidence,
                processingTime: processingTime,
                cacheHit: false,
                tags: partialResponse.metadata.tags
            ),
            usage: usage.map { u in
                AICommandResponse.Usage(
                    promptTokens: u.promptTokens,
                    completionTokens: u.completionTokens,
                    totalTokens: u.totalTokens,
                    cost: calculateCost(usage: u)
                )
            }
        )
    }
    
    private func createFallbackResponse(
        from content: String,
        requestId: String,
        processingTime: TimeInterval
    ) -> AICommandResponse {
        // Extract command from unstructured response
        let command = extractCommand(from: content) ?? content
        
        return AICommandResponse(
            requestId: requestId,
            result: AICommandResponse.Result(
                status: .partial,
                commands: [
                    AICommandResponse.Result.Command(
                        content: command,
                        type: .shell,
                        risk: AICommandResponse.Result.Command.RiskAssessment(
                            level: .low,
                            score: 0.1,
                            factors: ["Could not parse structured response"],
                            requiresConfirmation: true
                        )
                    )
                ],
                explanation: AICommandResponse.Result.Explanation(
                    summary: "Command extracted from unstructured response",
                    details: content
                )
            ),
            metadata: AICommandResponse.Metadata(
                model: config.model ?? config.provider.defaultModel,
                provider: config.provider.rawValue,
                confidence: 0.5,
                processingTime: processingTime
            )
        )
    }
    
    private func extractCommand(from text: String) -> String? {
        // Try to extract command from markdown code blocks
        if let range = text.range(of: "```\\w*\\n(.+?)\\n```", options: .regularExpression) {
            let code = String(text[range])
            return code
                .replacingOccurrences(of: "```\\w*\\n", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\\n```", with: "")
        }
        
        // Try to extract command from backticks
        if let range = text.range(of: "`(.+?)`", options: .regularExpression) {
            let code = String(text[range])
            return code.replacingOccurrences(of: "`", with: "")
        }
        
        return nil
    }
    
    private func performAPICall(_ request: UnifiedChatCompletionRequest) async throws -> UnifiedChatResponse {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let requestData = try encoder.encode(request)
        
        var urlRequest = URLRequest(url: URL(string: "\(config.baseURL ?? config.provider.baseURL)/chat/completions")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = requestData
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkTimeout
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.invalidResponse("HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UnifiedChatResponse.self, from: data)
    }
    
    private func calculateCost(usage: UnifiedChatResponse.Usage) -> Double {
        // Rough cost estimation (adjust based on actual pricing)
        let costPer1kTokens: Double
        switch config.provider {
        case .groq:
            costPer1kTokens = 0.002  // Example rate
        case .openai:
            costPer1kTokens = 0.03   // GPT-4 rate
        default:
            costPer1kTokens = 0.001
        }
        
        return Double(usage.totalTokens) / 1000.0 * costPer1kTokens
    }
}

// MARK: - Helper Types for API Communication

private struct UnifiedChatCompletionRequest: Encodable {
    let model: String
    let messages: [UnifiedChatMessage]
    let temperature: Double
    let maxTokens: Int
    let responseFormat: UnifiedResponseFormat?
}

private struct UnifiedResponseFormat: Encodable {
    let type: String
}

private struct UnifiedChatMessage: Encodable {
    enum Role: String, Encodable {
        case system, user, assistant
    }
    let role: Role
    let content: String
}

private struct UnifiedChatResponse: Decodable {
    let choices: [Choice]
    let usage: Usage?
    
    struct Choice: Decodable {
        let message: Message
        
        struct Message: Decodable {
            let content: String
        }
    }
    
    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
    }
}

// Partial response structure from AI (without requestId, timestamp, etc.)
private struct PartialAIResponse: Decodable {
    let result: AICommandResponse.Result
    let metadata: PartialMetadata
    
    struct PartialMetadata: Decodable {
        let model: String
        let provider: String
        let confidence: Double
        let tags: [String]?
    }
}
