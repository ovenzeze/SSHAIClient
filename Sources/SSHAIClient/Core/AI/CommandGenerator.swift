import Foundation

/// A rule-based command generator that provides basic command suggestions.
/// This serves as a baseline implementation and fallback when AI services are unavailable.
final class CommandGenerator: CommandGenerating, @unchecked Sendable {
    
    private let supportedLanguages = ["en-US", "en-GB", "en"]
    
    func generate(query: String, context: GenerationContext) async throws -> CommandSuggestion {
        // Validate input
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CommandGenerationError.invalidQuery("Query cannot be empty")
        }
        
        guard supportsLanguage(context.userPreferences.language) else {
            throw CommandGenerationError.unsupportedLanguage(context.userPreferences.language)
        }
        
        // Basic rule-based generation
        let suggestion = try generateBasicCommand(query: query, context: context)
        
        // Add a small delay to simulate AI processing
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        return suggestion
    }
    
    func supportsLanguage(_ language: String) -> Bool {
        return supportedLanguages.contains { lang in
            language.hasPrefix(lang) || lang.hasPrefix(language)
        }
    }
    
    // MARK: - Private Implementation
    
    private func generateBasicCommand(query: String, context: GenerationContext) throws -> CommandSuggestion {
        let lowercaseQuery = query.lowercased()
        
        // File operations
        if lowercaseQuery.contains("list") && (lowercaseQuery.contains("file") || lowercaseQuery.contains("directory")) {
            return CommandSuggestion(
                command: "ls -la",
                explanation: "Lists all files and directories with detailed information",
                risk: .safe,
                confidence: 0.9
            )
        }
        
        // Directory navigation
        if lowercaseQuery.contains("change directory") || lowercaseQuery.contains("go to") {
            if lowercaseQuery.contains("home") {
                return CommandSuggestion(
                    command: "cd ~",
                    explanation: "Changes to the home directory",
                    risk: .safe,
                    confidence: 0.95
                )
            }
            return CommandSuggestion(
                command: "cd <directory_name>",
                explanation: "Changes to the specified directory. Replace <directory_name> with your target.",
                risk: .safe,
                confidence: 0.7
            )
        }
        
        // System information
        if lowercaseQuery.contains("system info") || lowercaseQuery.contains("os version") {
            let command = context.host.osName.lowercased().contains("darwin") ? "sw_vers" : "uname -a"
            return CommandSuggestion(
                command: command,
                explanation: "Displays system information and version",
                risk: .safe,
                confidence: 0.8
            )
        }
        
        // Process management
        if lowercaseQuery.contains("running process") || lowercaseQuery.contains("list process") {
            return CommandSuggestion(
                command: "ps aux",
                explanation: "Lists all running processes with detailed information",
                risk: .safe,
                confidence: 0.85
            )
        }
        
        // Dangerous operations
        if lowercaseQuery.contains("delete") || lowercaseQuery.contains("remove") {
            if lowercaseQuery.contains("all") || lowercaseQuery.contains("everything") {
                return CommandSuggestion(
                    command: "# DANGEROUS: This operation could delete important files",
                    explanation: "This query requests potentially destructive file deletion. Please be more specific about what you want to delete.",
                    risk: .dangerous,
                    confidence: 0.9
                )
            }
            return CommandSuggestion(
                command: "rm <filename>",
                explanation: "Removes a file. Replace <filename> with the actual file name. Use 'rm -r' for directories.",
                risk: .caution,
                confidence: 0.6
            )
        }
        
        // Default fallback
        return CommandSuggestion(
            command: "# Unable to generate specific command",
            explanation: "Could not understand the request '\(query)'. Please try rephrasing or be more specific.",
            risk: .safe,
            confidence: 0.1
        )
    }
}
