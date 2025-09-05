import Foundation
import SSHAIClient

/// Standalone test program for the unified JSON schema
/// This demonstrates the schema working with real AI calls

@main
struct UnifiedSchemaTest {
    
    static func main() async {
        print("""
        ╔════════════════════════════════════════════════════╗
        ║     Unified JSON Schema Integration Test           ║
        ║     Testing with Groq GPT-OSS-120B                ║
        ╚════════════════════════════════════════════════════╝
        """)
        
        // Get API key from environment
        guard let apiKey = ProcessInfo.processInfo.environment["GROQ_API_KEY"] else {
            print("❌ Error: GROQ_API_KEY environment variable not set")
            print("   Run: export GROQ_API_KEY='your-api-key'")
            exit(1)
        }
        
        // Initialize the unified AI client
        let config = AIServiceConfig(
            provider: .groq,
            model: "openai/gpt-oss-120b",
            maxTokens: 1000,
            temperature: 0.1
        )
        
        let client = UnifiedAIClient(config: config, apiKey: apiKey)
        
        // Run tests
        await testBasicCommandGeneration(client: client)
        await testComplexScenarios(client: client)
        await testErrorHandling(client: client)
        await testJSONSerialization()
        
        print("\n✅ All tests completed!")
    }
    
    // MARK: - Test Basic Command Generation
    
    static func testBasicCommandGeneration(client: UnifiedAIClient) async {
        print("\n═══════════════════════════════════════════════════════")
        print("📝 Test 1: Basic Command Generation")
        print("═══════════════════════════════════════════════════════")
        
        // Create a structured request
        let request = AICommandRequest(
            input: AICommandRequest.Input(
                type: .naturalLanguage,
                content: "show me all Python files modified today",
                language: "en"
            ),
            context: AICommandRequest.Context(
                system: AICommandRequest.Context.SystemContext(
                    os: "Darwin",
                    osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                    architecture: "arm64"
                ),
                terminal: AICommandRequest.Context.TerminalContext(
                    shell: "zsh",
                    shellVersion: "5.9",
                    workingDirectory: FileManager.default.currentDirectoryPath,
                    environmentVariables: ["LANG": "en_US.UTF-8"]
                ),
                user: AICommandRequest.Context.UserContext(
                    username: NSUserName(),
                    permissions: .user,
                    preferences: AICommandRequest.Context.UserContext.UserPreferences(
                        preferSafeMode: true,
                        allowDestructiveCommands: false
                    )
                ),
                history: AICommandRequest.Context.HistoryContext(
                    recentCommands: ["ls", "cd /tmp", "git status"]
                )
            ),
            options: AICommandRequest.Options(
                maxTokens: 500,
                temperature: 0.1,
                stream: false
            )
        )
        
        print("\n📤 Request:")
        if let jsonString = try? request.toJSON(prettyPrinted: true) {
            // Print first 500 chars of request
            let preview = String(jsonString.prefix(500))
            print(preview + (jsonString.count > 500 ? "\n..." : ""))
        }
        
        do {
            let response = try await client.generateCommand(request)
            
            print("\n📥 Response:")
            print("   Status: \(response.result.status)")
            print("   Request ID: \(response.requestId)")
            print("   Provider: \(response.metadata.provider)")
            print("   Model: \(response.metadata.model)")
            print("   Confidence: \(String(format: "%.2f", response.metadata.confidence))")
            print("   Processing Time: \(String(format: "%.3fs", response.metadata.processingTime))")
            
            if let commands = response.result.commands {
                for (index, command) in commands.enumerated() {
                    print("\n   Command #\(index + 1):")
                    print("   └─ Content: \(command.content)")
                    print("      Type: \(command.type)")
                    print("      Risk: \(command.risk.level) (score: \(command.risk.score))")
                    
                    if let warnings = command.risk.warnings, !warnings.isEmpty {
                        print("      ⚠️  Warnings:")
                        for warning in warnings {
                            print("         • \(warning)")
                        }
                    }
                    
                    if let alternatives = command.alternatives, !alternatives.isEmpty {
                        print("      🔄 Alternatives:")
                        for alt in alternatives {
                            print("         • \(alt.command)")
                            print("           \(alt.description)")
                        }
                    }
                }
            }
            
            if let explanation = response.result.explanation {
                print("\n   📖 Explanation: \(explanation.summary)")
                if let steps = explanation.steps {
                    print("      Steps:")
                    for step in steps {
                        print("      \(step.order). \(step.description)")
                    }
                }
            }
            
            if let usage = response.usage {
                print("\n   📊 Usage:")
                print("      Tokens: \(usage.totalTokens) (prompt: \(usage.promptTokens), completion: \(usage.completionTokens))")
                if let cost = usage.cost {
                    print("      Cost: $\(String(format: "%.5f", cost))")
                }
            }
            
        } catch {
            print("\n❌ Error: \(error)")
        }
    }
    
    // MARK: - Test Complex Scenarios
    
    static func testComplexScenarios(client: UnifiedAIClient) async {
        print("\n═══════════════════════════════════════════════════════")
        print("🔧 Test 2: Complex Scenarios")
        print("═══════════════════════════════════════════════════════")
        
        let scenarios: [(String, AICommandRequest.Input.InputType)] = [
            ("rm -rf /tmp/*.log", .directCommand),
            ("create a backup of my database and compress it", .naturalLanguage),
            ("find . -name '*.txt' | xargs grep 'TODO'", .mixedIntent)
        ]
        
        for (content, inputType) in scenarios {
            print("\n🎯 Testing: \"\(content)\" (type: \(inputType))")
            
            let request = AICommandRequest(
                input: AICommandRequest.Input(
                    type: inputType,
                    content: content,
                    language: "en"
                ),
                context: createTestContext(safeMode: true),
                options: AICommandRequest.Options(maxTokens: 300)
            )
            
            do {
                let response = try await client.generateCommand(request)
                
                print("   Result: \(response.result.status)")
                
                if let command = response.result.commands?.first {
                    print("   Command: \(command.content)")
                    print("   Risk Level: \(command.risk.level) (\(command.risk.requiresConfirmation ? "requires confirmation" : "safe to execute"))")
                }
                
                if let error = response.result.error {
                    print("   ⚠️  \(error.type): \(error.message)")
                    if let suggestions = error.suggestions {
                        print("   Suggestions:")
                        for suggestion in suggestions {
                            print("      • \(suggestion)")
                        }
                    }
                }
                
            } catch {
                print("   ❌ Failed: \(error)")
            }
        }
    }
    
    // MARK: - Test Error Handling
    
    static func testErrorHandling(client: UnifiedAIClient) async {
        print("\n═══════════════════════════════════════════════════════")
        print("⚠️  Test 3: Error Handling")
        print("═══════════════════════════════════════════════════════")
        
        // Test with dangerous command in safe mode
        let dangerousRequest = AICommandRequest(
            input: AICommandRequest.Input(
                type: .directCommand,
                content: "sudo rm -rf /*",
                language: "en"
            ),
            context: createTestContext(safeMode: true),
            options: AICommandRequest.Options()
        )
        
        print("\n🔴 Testing dangerous command in safe mode...")
        
        do {
            let response = try await client.generateCommand(dangerousRequest)
            
            if response.result.status == .error || response.result.status == .needsClarification {
                print("   ✅ Correctly identified as dangerous/problematic")
                if let error = response.result.error {
                    print("   Error Type: \(error.type)")
                    print("   Message: \(error.message)")
                }
            } else if let command = response.result.commands?.first {
                if command.risk.level == .critical || command.risk.level == .high {
                    print("   ✅ Correctly marked as high risk: \(command.risk.level)")
                    print("   Requires Confirmation: \(command.risk.requiresConfirmation)")
                }
            }
        } catch {
            print("   Error during test: \(error)")
        }
    }
    
    // MARK: - Test JSON Serialization
    
    static func testJSONSerialization() {
        print("\n═══════════════════════════════════════════════════════")
        print("📄 Test 4: JSON Serialization/Deserialization")
        print("═══════════════════════════════════════════════════════")
        
        // Create a complete response object
        let response = AICommandResponse(
            requestId: UUID().uuidString,
            result: AICommandResponse.Result(
                status: .success,
                commands: [
                    AICommandResponse.Result.Command(
                        content: "find . -name '*.py' -mtime 0",
                        type: .shell,
                        risk: AICommandResponse.Result.Command.RiskAssessment(
                            level: .safe,
                            score: 0.1,
                            factors: ["read-only", "local scope"],
                            warnings: nil,
                            requiresConfirmation: false
                        ),
                        alternatives: [
                            AICommandResponse.Result.Command.Alternative(
                                command: "find . -name '*.py' -newermt 'today 00:00'",
                                description: "More precise time-based search",
                                tradeoffs: "Not portable to all systems"
                            )
                        ],
                        dependencies: ["find"],
                        platforms: ["Darwin", "Linux"]
                    )
                ],
                explanation: AICommandResponse.Result.Explanation(
                    summary: "Find Python files modified today",
                    details: "Uses the find command with -mtime flag",
                    steps: [
                        AICommandResponse.Result.Explanation.Step(
                            order: 1,
                            description: "Search from current directory",
                            command: "find .",
                            note: "Recursive by default"
                        ),
                        AICommandResponse.Result.Explanation.Step(
                            order: 2,
                            description: "Filter by file name pattern",
                            command: "-name '*.py'",
                            note: "Case sensitive match"
                        )
                    ],
                    references: ["man find"]
                )
            ),
            metadata: AICommandResponse.Metadata(
                model: "gpt-oss-120b",
                provider: "groq",
                confidence: 0.95,
                processingTime: 0.234,
                cacheHit: false,
                tags: ["file-search", "python"]
            ),
            usage: AICommandResponse.Usage(
                promptTokens: 150,
                completionTokens: 75,
                totalTokens: 225,
                cost: 0.00045
            )
        )
        
        do {
            // Serialize to JSON
            let jsonString = try response.toJSON(prettyPrinted: true)
            print("\n📤 Serialized JSON (first 600 chars):")
            print(String(jsonString.prefix(600)) + "...")
            
            // Deserialize back
            let decoded = try AICommandResponse.fromJSON(jsonString)
            
            // Verify round-trip
            print("\n✅ Round-trip verification:")
            print("   Request ID matches: \(decoded.requestId == response.requestId)")
            print("   Status matches: \(decoded.result.status == response.result.status)")
            print("   Command count: \(decoded.result.commands?.count ?? 0)")
            print("   Metadata confidence: \(decoded.metadata.confidence)")
            
            // Test request serialization too
            let request = createSampleRequest()
            let requestJSON = try request.toJSON(prettyPrinted: false)
            let decodedRequest = try AICommandRequest.fromJSON(requestJSON)
            
            print("\n✅ Request serialization:")
            print("   Input type matches: \(decodedRequest.input.type == request.input.type)")
            print("   Context preserved: \(decodedRequest.context.system.os == request.context.system.os)")
            print("   JSON size: \(requestJSON.count) bytes")
            
        } catch {
            print("\n❌ Serialization error: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    static func createTestContext(safeMode: Bool) -> AICommandRequest.Context {
        return AICommandRequest.Context(
            system: AICommandRequest.Context.SystemContext(
                os: "Darwin",
                osVersion: "23.6.0",
                architecture: "arm64",
                hostname: "test-mac.local"
            ),
            terminal: AICommandRequest.Context.TerminalContext(
                shell: "zsh",
                shellVersion: "5.9",
                workingDirectory: "/tmp/test",
                environmentVariables: ["TERM": "xterm-256color"],
                terminalType: "xterm-256color"
            ),
            user: AICommandRequest.Context.UserContext(
                username: "testuser",
                userId: "501",
                permissions: .user,
                preferences: AICommandRequest.Context.UserContext.UserPreferences(
                    preferSafeMode: safeMode,
                    allowDestructiveCommands: !safeMode,
                    preferVerboseOutput: false
                )
            ),
            history: AICommandRequest.Context.HistoryContext(
                recentCommands: ["ls", "pwd", "echo test"],
                sessionId: "test-session-123"
            )
        )
    }
    
    static func createSampleRequest() -> AICommandRequest {
        return AICommandRequest(
            input: AICommandRequest.Input(
                type: .naturalLanguage,
                content: "test command",
                language: "en"
            ),
            context: createTestContext(safeMode: true),
            options: AICommandRequest.Options()
        )
    }
}
