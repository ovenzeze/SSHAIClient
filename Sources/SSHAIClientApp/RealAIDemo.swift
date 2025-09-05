import SwiftUI
import SSHAIClient

/// Real working demo app showing AI integration
@available(macOS 11.0, *)
struct RealAIDemoApp: App {
    var body: some Scene {
        WindowGroup {
            AICommandView()
        }
    }
}

@available(macOS 11.0, *)
struct AICommandView: View {
    @StateObject private var viewModel = AICommandViewModel()
    @State private var userQuery = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("SSH AI Command Generator")
                .font(.largeTitle)
                .padding()
            
            HStack {
                if #available(macOS 12.0, *) {
                    TextField("Enter natural language query", text: $userQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            Task { await generateCommand() }
                        }
                } else {
                    TextField("Enter natural language query", text: $userQuery, onCommit: {
                        Task { await generateCommand() }
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Button("Generate") {
                    Task { await generateCommand() }
                }
                .disabled(userQuery.isEmpty || isLoading)
            }
            .padding()
            
            if isLoading {
                ProgressView("Generating command...")
                    .padding()
            }
            
            if let result = viewModel.lastResult {
                VStack(alignment: .leading, spacing: 10) {
                    if #available(macOS 11.0, *) {
                        Label("Command", systemImage: "terminal")
                            .font(.headline)
                    } else {
                        Text("Command")
                            .font(.headline)
                    }
                    
                    Text(result.command)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .modifier(TextSelectionCompat())
                    
                    HStack {
                        if #available(macOS 11.0, *) {
                            Label("Risk: \(result.risk.rawValue)", systemImage: riskIcon(for: result.risk))
                                .foregroundColor(riskColor(for: result.risk))
                        } else {
                            Text("Risk: \(result.risk.rawValue)")
                                .foregroundColor(riskColor(for: result.risk))
                        }
                        
                        Spacer()
                        
                        Text("Confidence: \(Int(result.confidence * 100))%")
                            .foregroundColor(.secondary)
                    }
                    
                    Text(result.explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
            }
            
            if let error = viewModel.lastError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func generateCommand() async {
        isLoading = true
        defer { isLoading = false }
        
        await viewModel.generateCommand(from: userQuery)
    }
    
    private func riskIcon(for risk: RiskLevel) -> String {
        switch risk {
        case .safe: return "checkmark.shield"
        case .caution: return "exclamationmark.triangle"
        case .dangerous: return "xmark.shield"
        }
    }
    
    private func riskColor(for risk: RiskLevel) -> Color {
        switch risk {
        case .safe: return .green
        case .caution: return .orange
        case .dangerous: return .red
        }
    }
}

// Compatibility modifier for text selection
@available(macOS 10.15, *)
private struct TextSelectionCompat: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 12.0, *) {
            content.textSelection(.enabled)
        } else {
            content
        }
    }
}

@MainActor
class AICommandViewModel: ObservableObject {
    @Published var lastResult: CommandSuggestion?
    @Published var lastError: String?
    
    private let aiClient: OpenAICompatibleClient
    
    init() {
        // Use environment variable for API key
        let config = AIServiceConfig(
            provider: .groq,
            model: "openai/gpt-oss-120b",
            maxTokens: 500,
            temperature: 0.1
        )
        
        // Create a simple API key provider that uses environment variables
        let keyManager = EnvironmentKeyManager()
        self.aiClient = OpenAICompatibleClient(
            config: config,
            onePasswordManager: keyManager
        )
    }
    
    func generateCommand(from query: String) async {
        do {
            let context = GenerationContext(
                host: HostInfo(
                    osName: "Darwin",
                    osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                    architecture: "arm64"
                ),
                shell: ShellInfo(name: "zsh", version: "5.9"),
                workingDirectory: FileManager.default.currentDirectoryPath,
                recentCommands: [],
                userPreferences: UserPreferences()
            )
            
            let suggestion = try await aiClient.generateCommand(query, context: context)
            self.lastResult = suggestion
            self.lastError = nil
        } catch {
            self.lastError = error.localizedDescription
            self.lastResult = nil
        }
    }
}

// Simple environment-based key manager for demo
final class EnvironmentKeyManager: OnePasswordManaging, @unchecked Sendable {
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
