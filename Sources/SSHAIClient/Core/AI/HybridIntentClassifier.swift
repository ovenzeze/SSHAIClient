import Foundation

/// HybridIntentClassifier routes a single user input into either:
/// - a shell command intent (direct execution), or
/// - an AI query intent (requires NL2CLI or dialogue).
///
/// The classifier composes multiple strategies in order:
/// 1) Local cache hit
/// 2) Heuristic rules (regex/features)
/// 3) On-device AI (Apple Intelligence) when available
/// 4) Remote API fallback
///
/// Input:
/// - rawInput: The exact text user typed in the input bar
/// - terminalContext: Optional lightweight context such as current directory, recent commands
///
/// Output:
/// - IntentResult carrying `type` (command|aiQuery), `confidence`, and optional `explanation`
///
/// Non-goals / Not implemented:
/// - Real ML model loading/inference; only the orchestration contract is defined
/// - Telemetry, rate limiting, and personalization store
final class HybridIntentClassifier {
	struct TerminalContext {
		let workingDirectory: String?
		let recentCommands: [String]
		let shell: String?
	}
	
	enum IntentType {
		case command
		case aiQuery
	}
	
	struct IntentResult {
		let type: IntentType
		let confidence: Double // 0.0 ~ 1.0
		let explanation: String // why the classifier decided so
	}
	
	/// Classify a single input using the multi-stage strategy described above.
	/// - Parameters:
	///   - rawInput: The user input string to be classified.
	///   - context: Terminal context to help the classifier.
	/// - Returns: `IntentResult` containing type, confidence, and explanation.
	func classify(rawInput: String, context: TerminalContext?) async -> IntentResult {
		// Logic outline (not implemented):
		// 1. Normalize input (trim, collapse whitespace) and check cache.
		// 2. Apply rules: look for command-like tokens (pipes, redirects, sudo, flags, shebangs).
		// 3. If available, call on-device AI with a short prompt including context.
		// 4. If still ambiguous, call remote API; cache the result for subsequent queries.
		// 5. Return the best-scored intent with explanation of contributing signals.
		return IntentResult(type: .aiQuery, confidence: 0.5, explanation: "stub")
	}
}
