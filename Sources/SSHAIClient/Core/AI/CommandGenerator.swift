import Foundation

/// CommandGenerator converts a natural-language query into a shell command suggestion.
/// It also computes a risk level and embeds a short explanation for user confirmation.
///
/// Inputs:
/// - query: Natural language instruction from user
/// - context: Rich execution context (host, shell, working dir, recent commands, env, preferences)
///
/// Outputs:
/// - CommandSuggestion: Structured suggestion containing `command`, `explanation`, `risk`
///
/// Not implemented:
/// - Actual prompt building and model invocation (local or remote)
/// - Shell dialect adaptation and OS-distribution branching
/// - Static analysis/sandbox dry-run
final class CommandGenerator {
	struct HostInfo {
		let osName: String
		let osVersion: String
		let architecture: String
	}
	
	struct ShellInfo {
		let name: String // zsh, bash, fish
		let version: String?
	}
	
	struct UserPreferences {
		let preferSafeFlags: Bool
		let preferOneLiners: Bool
		let language: String // e.g., "en-US"
	}
	
	struct GenerationContext {
		let host: HostInfo
		let shell: ShellInfo
		let workingDirectory: String
		let recentCommands: [String]
		let environment: [String: String]
		let userPreferences: UserPreferences
	}
	
	enum RiskLevel: String {
		case safe
		case caution
		case dangerous
	}
	
	struct CommandSuggestion {
		let command: String
		let explanation: String
		let risk: RiskLevel
		let confidence: Double
	}
	
	/// Generate a shell command suggestion based on a natural language query and context.
	/// - Parameters:
	///   - query: User's NL instruction.
	///   - context: Execution context to steer the generation for correctness and safety.
	/// - Returns: `CommandSuggestion` with command, explanation, risk level and confidence.
	func generate(query: String, context: GenerationContext) async throws -> CommandSuggestion {
		// Logic (not implemented):
		// 1. Build a structured prompt with host/shell/context constraints and safety directives.
		// 2. Invoke on-device AI if available; otherwise remote service.
		// 3. Parse response; validate command (basic heuristics) and compute risk.
		// 4. Return CommandSuggestion.
		throw NSError(domain: "CommandGenerator", code: -1)
	}
}
