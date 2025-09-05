import Foundation
import SSHAIClient

// Command-line executable to test real AI API calls

@main
struct TestAI {
    static func main() async {
        print("🤖 SSH AI Client - Real API Test")
        print("=" * 40)
        
        // Test configuration using GPT-OSS-120B model
        let config = AIServiceConfig(
            provider: .groq,
            model: "openai/gpt-oss-120b",
            maxTokens: 500,
            temperature: 0.1
        )
        
        // Create client with environment key manager
        let keyManager = SimpleEnvironmentKeyManager()
        let client = OpenAICompatibleClient(
            config: config,
            onePasswordManager: keyManager
        )
        
        // Test queries
        let testQueries = [
            "list all files in the current directory",
            "find all Python files modified in the last 7 days",
            "show disk usage of the home directory",
            "check which process is using port 8080",
            "create a backup of all .conf files"
        ]
        
        // Create context
        let context = GenerationContext(
            host: HostInfo(
                osName: "Darwin",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                architecture: "arm64"
            ),
            shell: ShellInfo(name: "zsh", version: "5.9"),
            workingDirectory: FileManager.default.currentDirectoryPath,
            recentCommands: ["ls -la", "cd ~", "git status"],
            userPreferences: UserPreferences()
        )
        
        print("\n📋 Testing Command Generation:")
        print("-" * 40)
        
        for query in testQueries {
            print("\n🔍 Query: \"\(query)\"")
            
            do {
                let suggestion = try await client.generateCommand(query, context: context)
                
                print("   ✅ Command: \(suggestion.command)")
                print("   📊 Confidence: \(Int(suggestion.confidence * 100))%")
                print("   ⚠️  Risk: \(suggestion.risk.rawValue)")
                print("   💬 Explanation: \(suggestion.explanation)")
            } catch {
                print("   ❌ Error: \(error)")
            }
        }
        
        print("\n\n🧠 Testing Intent Classification:")
        print("-" * 40)
        
        let intentQueries = [
            "ls -la",  // Direct command
            "how do I check disk space?",  // Question
            "show me all running processes"  // Natural language
        ]
        
        // Create terminal context for intent classification
        let terminalContext = TerminalContext(
            workingDirectory: FileManager.default.currentDirectoryPath,
            recentCommands: ["ls -la", "cd ~", "git status"],
            shell: "zsh",
            environment: [:]
        )
        
        for query in intentQueries {
            print("\n🔍 Query: \"\(query)\"")
            
            do {
                let result = try await client.classifyIntent(query, context: terminalContext)
                
                let intentName: String
                switch result.type {
                case .command:
                    intentName = "Direct Command"
                case .aiQuery:
                    intentName = "AI Query"
                case .ambiguous:
                    intentName = "Ambiguous"
                }
                
                print("   🎯 Intent: \(intentName)")
                print("   📊 Confidence: \(Int(result.confidence * 100))%")
                print("   💬 Explanation: \(result.explanation)")
            } catch {
                print("   ❌ Error: \(error)")
            }
        }
        
        print("\n\n✨ Test completed!")
    }
}

// Simplified environment key manager for testing
final class SimpleEnvironmentKeyManager: OnePasswordManaging, @unchecked Sendable {
    func getAPIKey(for provider: AIProvider) async throws -> String {
        // Try to get from environment variable
        let envVar = provider.environmentVariableName
        guard let key = ProcessInfo.processInfo.environment[envVar] else {
            print("⚠️  No API key found in environment variable: \(envVar)")
            print("   Set it with: export \(envVar)='your-api-key'")
            throw AIServiceError.apiKeyMissing
        }
        return key
    }
    
    func getSecret(itemName: String, field: String) async throws -> String {
        throw AIServiceError.configurationInvalid("Not implemented")
    }
    
    func storeAPIKey(_ apiKey: String, for provider: AIProvider, notes: String?) async throws {
        // Not implemented for testing
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
        // Not implemented for testing
    }
}

// Helper to repeat string
extension String {
    static func *(lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}
