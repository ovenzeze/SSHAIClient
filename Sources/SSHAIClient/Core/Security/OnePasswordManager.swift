import Foundation

// MARK: - OnePassword Protocol

/// Protocol for 1Password management operations
public protocol OnePasswordManaging: Sendable {
    func getAPIKey(for provider: AIProvider) async throws -> String
    func getSecret(itemName: String, field: String) async throws -> String
    func storeAPIKey(_ apiKey: String, for provider: AIProvider, notes: String?) async throws
    func verifyOnePasswordCLI() async throws
    func listAIProviderItems() async throws -> [String]
    func getAPIKeyWithFallback(for provider: AIProvider) async throws -> String
    func setupDefaultProviders() async throws
}

/// Manager for secure API key retrieval using 1Password CLI
public class OnePasswordManager: OnePasswordManaging, @unchecked Sendable {
    
    public enum OnePasswordError: Error, LocalizedError {
        case cliNotInstalled
        case notSignedIn
        case itemNotFound(String)
        case invalidResponse(String)
        case executionFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .cliNotInstalled:
                return "1Password CLI is not installed. Please install it using 'brew install 1password-cli'"
            case .notSignedIn:
                return "Not signed in to 1Password. Please run 'op signin' first"
            case .itemNotFound(let item):
                return "1Password item not found: \(item)"
            case .invalidResponse(let details):
                return "Invalid response from 1Password CLI: \(details)"
            case .executionFailed(let details):
                return "1Password CLI execution failed: \(details)"
            }
        }
    }
    
    /// Vault ID for SSH AI Client secrets (can be configured)
    private let vaultID: String
    private let timeout: TimeInterval
    
    public init(vaultID: String = "Personal", timeout: TimeInterval = 10.0) {
        self.vaultID = vaultID
        self.timeout = timeout
    }
    
    /// Get API key for AI provider from 1Password
    public func getAPIKey(for provider: AIProvider) async throws -> String {
        let itemName = provider.onePasswordItemName
        return try await getSecret(itemName: itemName, field: "credential")
    }
    
    /// Get a generic secret from 1Password
    public func getSecret(itemName: String, field: String = "password") async throws -> String {
        // First check if 1Password CLI is available
        try await verifyOnePasswordCLI()
        
        // Construct the command to get the secret
        let command = "op item get \"\(itemName)\" --field \(field) --vault \"\(vaultID)\""
        
        let result = try await executeCommand(command)
        
        guard !result.isEmpty else {
            throw OnePasswordError.itemNotFound(itemName)
        }
        
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Store or update an API key in 1Password
    public func storeAPIKey(_ apiKey: String, for provider: AIProvider, notes: String? = nil) async throws {
        let itemName = provider.onePasswordItemName
        let category = "API Credential"
        
        // Check if item already exists
        let itemExists = await checkItemExists(itemName)
        
        if itemExists {
            // Update existing item
            let command = "op item edit \"\(itemName)\" credential=\(apiKey) --vault \"\(vaultID)\""
            _ = try await executeCommand(command)
        } else {
            // Create new item
            var command = "op item create --category=\"\(category)\" --title=\"\(itemName)\" credential=\(apiKey) --vault \"\(vaultID)\""
            
            if let notes = notes {
                command += " --notes=\"\(notes)\""
            }
            
            _ = try await executeCommand(command)
        }
    }
    
    /// Check if 1Password CLI is installed and user is signed in
    public func verifyOnePasswordCLI() async throws {
        // Check if op command is available
        do {
            _ = try await executeCommand("which op")
        } catch {
            throw OnePasswordError.cliNotInstalled
        }
        
        // Check if signed in
        do {
            _ = try await executeCommand("op whoami")
        } catch {
            throw OnePasswordError.notSignedIn
        }
    }
    
    /// List available AI provider items in 1Password
    public func listAIProviderItems() async throws -> [String] {
        let command = "op item list --vault \"\(vaultID)\" --format json"
        let jsonOutput = try await executeCommand(command)
        
        guard let data = jsonOutput.data(using: .utf8) else {
            throw OnePasswordError.invalidResponse("Could not parse JSON response")
        }
        
        struct OnePasswordItem: Codable {
            let title: String
            let category: String
        }
        
        do {
            let items = try JSONDecoder().decode([OnePasswordItem].self, from: data)
            return items
                .filter { $0.category.lowercased().contains("credential") || $0.category.lowercased().contains("api") }
                .map { $0.title }
        } catch {
            throw OnePasswordError.invalidResponse("Could not decode JSON: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func checkItemExists(_ itemName: String) async -> Bool {
        do {
            _ = try await executeCommand("op item get \"\(itemName)\" --vault \"\(vaultID)\"")
            return true
        } catch {
            return false
        }
    }
    
    private func executeCommand(_ command: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.launchPath = "/bin/sh"
            task.arguments = ["-c", command]
            
            let pipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = pipe
            task.standardError = errorPipe
            
            task.terminationHandler = { process in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                if process.terminationStatus != 0 {
                    let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: OnePasswordError.executionFailed(errorString))
                    return
                }
                
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }
            
            // Set up timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if task.isRunning {
                    task.terminate()
                    continuation.resume(throwing: OnePasswordError.executionFailed("Command timeout"))
                }
            }
            
            task.launch()
        }
    }
}

// MARK: - AIProvider Extension for 1Password Integration

public extension AIProvider {
    /// Standard item name in 1Password for each AI provider
    var onePasswordItemName: String {
        switch self {
        case .groq:
            return "Groq API Key"
        case .openai:
            return "OpenAI API Key"
        case .claude:
            return "Anthropic Claude API Key"
        case .ollama:
            return "Ollama API Key"
        case .custom:
            return "Custom AI API Key"
        }
    }
    
    /// Environment variable name for the API key
    var environmentVariableName: String {
        switch self {
        case .groq:
            return "GROQ_API_KEY"
        case .openai:
            return "OPENAI_API_KEY"
        case .claude:
            return "ANTHROPIC_API_KEY"
        case .ollama:
            return "OLLAMA_API_KEY"
        case .custom:
            return "CUSTOM_AI_API_KEY"
        }
    }
}

// MARK: - Convenience Methods

public extension OnePasswordManager {
    /// Get API key with fallback to environment variable
    func getAPIKeyWithFallback(for provider: AIProvider) async throws -> String {
        // First try 1Password
        do {
            return try await getAPIKey(for: provider)
        } catch {
            // Fallback to environment variable
            if let envKey = ProcessInfo.processInfo.environment[provider.environmentVariableName],
               !envKey.isEmpty {
                return envKey
            }
            
            // If both fail, re-throw the original 1Password error
            throw error
        }
    }
    
    /// Setup initial API keys for common providers
    func setupDefaultProviders() async throws {
        print("Setting up API keys for AI providers...")
        
        for provider in [AIProvider.groq, .openai, .claude] {
            do {
                _ = try await getAPIKey(for: provider)
                print("✅ \(provider.displayName): API key found")
            } catch OnePasswordError.itemNotFound {
                print("⚠️  \(provider.displayName): No API key found in 1Password")
                print("   Create an item named '\(provider.onePasswordItemName)' with your API key")
            } catch {
                print("❌ \(provider.displayName): Error retrieving API key - \(error)")
            }
        }
    }
}
