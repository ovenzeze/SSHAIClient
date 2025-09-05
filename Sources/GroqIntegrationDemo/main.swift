import Foundation
import SSHAIClient

/// Comprehensive demo showcasing Groq GPT-OSS-120B integration
/// This demonstrates real-world AI command generation and intent classification

@main
struct GroqIntegrationDemo {
    
    static func main() async {
        print("""
        ╔══════════════════════════════════════════════════════════╗
        ║    SSH AI Client - Groq GPT-OSS-120B Integration Demo    ║
        ╚══════════════════════════════════════════════════════════╝
        """)
        
        // Initialize the AI client with GPT-OSS-120B
        let client = await initializeClient()
        
        // Run comprehensive tests
        await runCommandGenerationDemo(client: client)
        await runIntentClassificationDemo(client: client)
        await runInteractiveDemo(client: client)
        
        print("\n✅ All demonstrations completed successfully!")
    }
    
    static func initializeClient() async -> OpenAICompatibleClient {
        print("\n🔧 Initializing Groq AI Client...")
        print("   Model: GPT-OSS-120B (120 billion parameters)")
        print("   Provider: Groq Cloud API")
        
        let config = AIServiceConfig(
            provider: .groq,
            model: "openai/gpt-oss-120b",
            maxTokens: 1000,
            temperature: 0.1,
            timeout: 30.0,
            maxRetries: 3
        )
        
        let keyManager = EnvironmentBasedKeyManager()
        let client = OpenAICompatibleClient(
            config: config,
            onePasswordManager: keyManager
        )
        
        // Test connection
        do {
            let connected = try await client.testConnection()
            if connected {
                print("   ✓ Connection established successfully")
            }
        } catch {
            print("   ⚠️ Connection test failed: \(error)")
        }
        
        return client
    }
    
    static func runCommandGenerationDemo(client: OpenAICompatibleClient) async {
        print("""
        
        ═══════════════════════════════════════════════════════════
        📝 Command Generation Demo
        ═══════════════════════════════════════════════════════════
        """)
        
        let testCases: [(query: String, description: String)] = [
            ("find large files over 100MB", "System maintenance"),
            ("monitor network traffic on port 443", "Network monitoring"),
            ("compress and encrypt backup files", "Security operation"),
            ("analyze system performance metrics", "Performance tuning"),
            ("clean up docker containers and images", "Container management")
        ]
        
        let context = GenerationContext(
            host: HostInfo(
                osName: "Darwin",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: "arm64"
            ),
            shell: ShellInfo(name: "zsh", version: "5.9"),
            workingDirectory: FileManager.default.currentDirectoryPath,
            recentCommands: ["docker ps", "git status", "kubectl get pods"],
            userPreferences: UserPreferences(
                preferSafeFlags: true,
                preferOneLiners: false
            )
        )
        
        for (query, description) in testCases {
            print("\n🎯 \(description)")
            print("   Query: \"\(query)\"")
            
            do {
                let suggestion = try await client.generateCommand(query, context: context)
                
                print("   └─ Command: \(formatCommand(suggestion.command))")
                print("      Risk: \(formatRisk(suggestion.risk))")
                print("      Confidence: \(formatConfidence(suggestion.confidence))")
                print("      Explanation: \(suggestion.explanation)")
            } catch {
                print("   └─ ❌ Error: \(error.localizedDescription)")
            }
        }
    }
    
    static func runIntentClassificationDemo(client: OpenAICompatibleClient) async {
        print("""
        
        ═══════════════════════════════════════════════════════════
        🧠 Intent Classification Demo
        ═══════════════════════════════════════════════════════════
        """)
        
        let testInputs = [
            "docker-compose up -d",
            "how do I set up SSH keys?",
            "git commit -m 'feat: add authentication'",
            "explain kubernetes pods",
            "chmod 755 script.sh",
            "what's the best way to monitor CPU usage?"
        ]
        
        let context = TerminalContext(
            workingDirectory: "/Users/demo/projects",
            recentCommands: ["git add .", "npm test", "docker build"],
            shell: "zsh",
            environment: ["NODE_ENV": "development"]
        )
        
        for input in testInputs {
            print("\n📌 Input: \"\(input)\"")
            
            do {
                let result = try await client.classifyIntent(input, context: context)
                
                let intentEmoji = switch result.type {
                case .command: "⚡"
                case .aiQuery: "🤖"
                case .ambiguous: "❓"
                }
                
                print("   └─ \(intentEmoji) Classification: \(formatIntent(result.type))")
                print("      Confidence: \(formatConfidence(result.confidence))")
                print("      Reason: \(result.explanation)")
            } catch {
                print("   └─ ❌ Error: \(error.localizedDescription)")
            }
        }
    }
    
    static func runInteractiveDemo(client: OpenAICompatibleClient) async {
        print("""
        
        ═══════════════════════════════════════════════════════════
        💬 Interactive Session Demo
        ═══════════════════════════════════════════════════════════
        """)
        
        let complexQueries = [
            "Set up a monitoring script that checks disk usage every hour and sends an alert if it exceeds 80%",
            "Create a secure backup strategy for PostgreSQL database with encryption",
            "Optimize nginx configuration for high-traffic website"
        ]
        
        let context = GenerationContext(
            host: HostInfo(
                osName: "Darwin",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: "arm64"
            ),
            shell: ShellInfo(name: "zsh", version: "5.9"),
            workingDirectory: "/opt/services",
            recentCommands: [],
            userPreferences: UserPreferences(
                preferSafeFlags: true,
                preferOneLiners: false
            )
        )
        
        for query in complexQueries {
            print("\n🔮 Complex Query:")
            print("   \"\(query)\"")
            print("")
            
            do {
                let suggestion = try await client.generateCommand(query, context: context)
                
                print("   📦 Generated Solution:")
                print("   " + String(repeating: "─", count: 50))
                
                // Format multi-line commands nicely
                let lines = suggestion.command.split(separator: "\n")
                for line in lines {
                    print("   \(line)")
                }
                
                print("   " + String(repeating: "─", count: 50))
                print("")
                print("   📊 Analysis:")
                print("   • Risk Level: \(formatRisk(suggestion.risk))")
                print("   • Confidence: \(formatConfidence(suggestion.confidence))")
                print("   • Explanation: \(suggestion.explanation)")
                
            } catch {
                print("   └─ ❌ Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Helper Functions
    
    static func formatCommand(_ command: String) -> String {
        return "`\(command)`"
    }
    
    static func formatRisk(_ risk: RiskLevel) -> String {
        switch risk {
        case .safe:
            return "✅ Safe"
        case .caution:
            return "⚠️ Caution"
        case .dangerous:
            return "🔴 Dangerous"
        }
    }
    
    static func formatConfidence(_ confidence: Double) -> String {
        let percentage = Int(confidence * 100)
        let bars = Int(confidence * 10)
        let barString = String(repeating: "▰", count: bars) + String(repeating: "▱", count: 10 - bars)
        return "\(barString) \(percentage)%"
    }
    
    static func formatIntent(_ type: IntentType) -> String {
        switch type {
        case .command:
            return "Direct Command"
        case .aiQuery:
            return "AI Query"
        case .ambiguous:
            return "Ambiguous"
        }
    }
}

// MARK: - Environment-based Key Manager

final class EnvironmentBasedKeyManager: OnePasswordManaging, @unchecked Sendable {
    
    func getAPIKey(for provider: AIProvider) async throws -> String {
        guard let key = ProcessInfo.processInfo.environment[provider.environmentVariableName] else {
            throw AIServiceError.apiKeyMissing
        }
        return key
    }
    
    func getSecret(itemName: String, field: String) async throws -> String {
        throw AIServiceError.configurationInvalid("Not implemented")
    }
    
    func storeAPIKey(_ apiKey: String, for provider: AIProvider, notes: String?) async throws {
        // Not implemented for demo
    }
    
    func verifyOnePasswordCLI() async throws {
        // Not needed for environment-based keys
    }
    
    func listAIProviderItems() async throws -> [String] {
        return []
    }
    
    func getAPIKeyWithFallback(for provider: AIProvider) async throws -> String {
        return try await getAPIKey(for: provider)
    }
    
    func setupDefaultProviders() async throws {
        // Not implemented for demo
    }
}
