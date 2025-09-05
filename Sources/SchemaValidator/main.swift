import Foundation
import SSHAIClient

/// Lightweight validation of the unified JSON schema
/// Focus on structure validation without heavy API calls

@main
struct SchemaValidator {
    
    static func main() async {
        print("""
        ╔════════════════════════════════════════════════════╗
        ║   Unified JSON Schema Validation & Demo            ║
        ║   Lightweight Testing (No API Overload)            ║
        ╚════════════════════════════════════════════════════╝
        """)
        
        // Test 1: Schema Creation and Serialization
        testSchemaCreation()
        
        // Test 2: JSON Round-trip
        testJSONRoundTrip()
        
        // Test 3: Mock AI Response Integration
        testMockAIIntegration()
        
        // Test 4: Single API Call with proper schema (if API key available)
        if ProcessInfo.processInfo.environment["GROQ_API_KEY"] != nil {
            print("\n📡 Testing with real API (single call)...")
            await testSingleAPICall()
        } else {
            print("\n⚠️  Skipping API test (no GROQ_API_KEY set)")
        }
        
        print("\n✅ Validation completed successfully!")
    }
    
    // MARK: - Test 1: Schema Creation
    
    static func testSchemaCreation() {
        print("\n═══════════════════════════════════════════════════════")
        print("🔨 Test 1: Schema Creation and Structure")
        print("═══════════════════════════════════════════════════════")
        
        // Create a request with all fields populated
        let request = AICommandRequest(
            requestId: "test-\(UUID().uuidString)",
            timestamp: Date(),
            input: AICommandRequest.Input(
                type: .naturalLanguage,
                content: "list all files",
                language: "en"
            ),
            context: AICommandRequest.Context(
                system: AICommandRequest.Context.SystemContext(
                    os: "Darwin",
                    osVersion: "23.6.0",
                    architecture: "arm64",
                    hostname: "test.local",
                    kernelVersion: "23.6.0"
                ),
                terminal: AICommandRequest.Context.TerminalContext(
                    shell: "zsh",
                    shellVersion: "5.9",
                    workingDirectory: "/tmp",
                    environmentVariables: ["TERM": "xterm-256color"],
                    terminalType: "xterm-256color"
                ),
                user: AICommandRequest.Context.UserContext(
                    username: "testuser",
                    userId: "501",
                    permissions: .admin,
                    preferences: AICommandRequest.Context.UserContext.UserPreferences(
                        preferSafeMode: true,
                        allowDestructiveCommands: false,
                        preferVerboseOutput: true,
                        customAliases: ["ll": "ls -la"]
                    )
                ),
                history: AICommandRequest.Context.HistoryContext(
                    recentCommands: ["ls", "pwd", "cd /tmp"],
                    sessionId: "session-123",
                    sessionStartTime: Date()
                )
            ),
            options: AICommandRequest.Options(
                maxTokens: 100,
                temperature: 0.1,
                stream: false,
                timeout: 30.0,
                model: "test-model"
            )
        )
        
        print("\n✅ Request created successfully")
        print("   Request ID: \(request.requestId)")
        print("   Input type: \(request.input.type)")
        print("   Context OS: \(request.context.system.os)")
        print("   User permissions: \(request.context.user.permissions?.rawValue ?? "none")")
        print("   Safe mode: \(request.context.user.preferences?.preferSafeMode ?? false)")
    }
    
    // MARK: - Test 2: JSON Round-trip
    
    static func testJSONRoundTrip() {
        print("\n═══════════════════════════════════════════════════════")
        print("🔄 Test 2: JSON Serialization Round-trip")
        print("═══════════════════════════════════════════════════════")
        
        // Create a complex response
        let originalResponse = AICommandResponse(
            requestId: "test-123",
            timestamp: Date(),
            result: AICommandResponse.Result(
                status: .success,
                commands: [
                    AICommandResponse.Result.Command(
                        id: "cmd-1",
                        content: "ls -la | grep '.txt'",
                        type: .pipeline,
                        risk: AICommandResponse.Result.Command.RiskAssessment(
                            level: .safe,
                            score: 0.1,
                            factors: ["read-only", "local scope"],
                            warnings: nil,
                            requiresConfirmation: false
                        ),
                        alternatives: [
                            AICommandResponse.Result.Command.Alternative(
                                command: "find . -name '*.txt'",
                                description: "Recursive search",
                                tradeoffs: "Slower but more thorough"
                            )
                        ],
                        dependencies: ["ls", "grep"],
                        platforms: ["Darwin", "Linux"]
                    )
                ],
                explanation: AICommandResponse.Result.Explanation(
                    summary: "List text files in current directory",
                    details: "Uses ls with grep to filter",
                    steps: [
                        AICommandResponse.Result.Explanation.Step(
                            order: 1,
                            description: "List all files",
                            command: "ls -la",
                            note: "Including hidden files"
                        ),
                        AICommandResponse.Result.Explanation.Step(
                            order: 2,
                            description: "Filter for .txt",
                            command: "grep '.txt'",
                            note: "Case sensitive"
                        )
                    ],
                    references: ["man ls", "man grep"]
                ),
                error: nil
            ),
            metadata: AICommandResponse.Metadata(
                model: "test-model",
                provider: "test",
                confidence: 0.95,
                processingTime: 0.123,
                cacheHit: false,
                tags: ["file-ops", "search"]
            ),
            usage: AICommandResponse.Usage(
                promptTokens: 100,
                completionTokens: 50,
                totalTokens: 150,
                cost: 0.0003
            )
        )
        
        do {
            // Serialize to JSON
            let jsonString = try originalResponse.toJSON(prettyPrinted: true)
            let jsonData = jsonString.data(using: .utf8)!
            
            print("\n📤 Serialized JSON:")
            print("   Size: \(jsonData.count) bytes")
            print("   Valid JSON: \(isValidJSON(jsonString))")
            
            // Show structure preview
            if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                print("   Top-level keys: \(jsonObject.keys.sorted().joined(separator: ", "))")
                
                if let result = jsonObject["result"] as? [String: Any] {
                    print("   Result status: \(result["status"] ?? "unknown")")
                    if let commands = result["commands"] as? [[String: Any]] {
                        print("   Commands count: \(commands.count)")
                    }
                }
            }
            
            // Deserialize back
            let decoded = try AICommandResponse.fromJSON(jsonString)
            
            // Verify key fields match
            print("\n✅ Round-trip verification:")
            print("   Request ID: \(decoded.requestId == originalResponse.requestId ? "✓" : "✗")")
            print("   Status: \(decoded.result.status == originalResponse.result.status ? "✓" : "✗")")
            print("   Command count: \(decoded.result.commands?.count == originalResponse.result.commands?.count ? "✓" : "✗")")
            print("   Confidence: \(decoded.metadata.confidence == originalResponse.metadata.confidence ? "✓" : "✗")")
            
            if let originalCmd = originalResponse.result.commands?.first,
               let decodedCmd = decoded.result.commands?.first {
                print("   Command content: \(decodedCmd.content == originalCmd.content ? "✓" : "✗")")
                print("   Risk level: \(decodedCmd.risk.level == originalCmd.risk.level ? "✓" : "✗")")
            }
            
        } catch {
            print("❌ Round-trip failed: \(error)")
        }
    }
    
    // MARK: - Test 3: Mock AI Integration
    
    static func testMockAIIntegration() {
        print("\n═══════════════════════════════════════════════════════")
        print("🤖 Test 3: Mock AI Response Integration")
        print("═══════════════════════════════════════════════════════")
        
        // Simulate what the AI would return (partial response)
        let mockAIResponse = """
        {
          "result": {
            "status": "success",
            "commands": [{
              "id": "ai-cmd-001",
              "content": "find /var/log -name '*.log' -size +100M",
              "type": "shell",
              "risk": {
                "level": "safe",
                "score": 0.1,
                "factors": ["read-only operation"],
                "requiresConfirmation": false
              },
              "dependencies": ["find"]
            }],
            "explanation": {
              "summary": "Find large log files",
              "details": "Searches for log files larger than 100MB in /var/log"
            }
          },
          "metadata": {
            "model": "gpt-oss-120b",
            "provider": "groq",
            "confidence": 0.92,
            "tags": ["file-search", "system-admin"]
          }
        }
        """
        
        // Parse the mock response
        if let data = mockAIResponse.data(using: .utf8) {
            do {
                let decoder = JSONDecoder()
                let partialResponse = try decoder.decode(PartialAIResponse.self, from: data)
                
                // Convert to full response
                let fullResponse = AICommandResponse(
                    requestId: UUID().uuidString,
                    timestamp: Date(),
                    result: partialResponse.result,
                    metadata: AICommandResponse.Metadata(
                        model: partialResponse.metadata.model,
                        provider: partialResponse.metadata.provider,
                        confidence: partialResponse.metadata.confidence,
                        processingTime: 0.234,
                        cacheHit: false,
                        tags: partialResponse.metadata.tags
                    ),
                    usage: nil
                )
                
                print("\n✅ Mock AI response parsed successfully:")
                print("   Status: \(fullResponse.result.status)")
                if let cmd = fullResponse.result.commands?.first {
                    print("   Command: \(cmd.content)")
                    print("   Type: \(cmd.type)")
                    print("   Risk: \(cmd.risk.level) (score: \(cmd.risk.score))")
                }
                print("   Model: \(fullResponse.metadata.model)")
                print("   Confidence: \(String(format: "%.2f", fullResponse.metadata.confidence))")
                
            } catch {
                print("❌ Failed to parse mock response: \(error)")
            }
        }
    }
    
    // MARK: - Test 4: Single API Call
    
    static func testSingleAPICall() async {
        print("\n═══════════════════════════════════════════════════════")
        print("🌐 Test 4: Single Real API Call with Schema")
        print("═══════════════════════════════════════════════════════")
        
        guard let apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] else {
            print("⚠️  No API key available")
            return
        }
        
        let config = AIServiceConfig(
            provider: .groq,
            model: "openai/gpt-oss-120b",
            maxTokens: 200,  // Keep it small
            temperature: 0.1
        )
        
        let client = UnifiedAIClient(config: config, apiKey: apiKey)
        
        // Simple request
        let request = AICommandRequest(
            input: AICommandRequest.Input(
                type: .directCommand,
                content: "echo hello",
                language: "en"
            ),
            context: AICommandRequest.Context(
                system: AICommandRequest.Context.SystemContext(
                    os: "Darwin",
                    osVersion: "23.6.0",
                    architecture: "arm64"
                ),
                terminal: AICommandRequest.Context.TerminalContext(
                    shell: "bash",
                    workingDirectory: "/tmp"
                ),
                user: AICommandRequest.Context.UserContext(
                    permissions: .user,
                    preferences: AICommandRequest.Context.UserContext.UserPreferences(
                        preferSafeMode: true
                    )
                )
            ),
            options: AICommandRequest.Options(
                maxTokens: 100,
                temperature: 0.1
            )
        )
        
        print("\n📤 Sending request for: '\(request.input.content)'")
        
        do {
            let response = try await client.generateCommand(request)
            
            print("\n✅ Response received:")
            print("   Status: \(response.result.status)")
            print("   Request ID: \(response.requestId)")
            
            if let cmd = response.result.commands?.first {
                print("   Generated command: \(cmd.content)")
                print("   Risk assessment: \(cmd.risk.level)")
            }
            
            print("   Processing time: \(String(format: "%.3fs", response.metadata.processingTime))")
            
        } catch {
            print("❌ API call failed: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    static func isValidJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
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
