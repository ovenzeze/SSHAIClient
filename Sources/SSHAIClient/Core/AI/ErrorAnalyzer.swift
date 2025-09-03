import Foundation

/// ErrorAnalyzer inspects a failed command execution and produces fix suggestions.
/// The analyzer uses rule-based patterns and AI-backed reasoning to classify the error
/// and propose actionable fixes, optionally with one-click apply flows.
///
/// Inputs:
/// - command: The original command string executed over SSH
/// - result: The execution result including exit code and stderr
/// - context: Minimal execution context (cwd, host, shell)
///
/// Outputs:
/// - Analysis containing `errorType`, `explanation`, and a ranked list of `FixSuggestion`s
///
/// Not implemented:
/// - Real pattern library; similarity search; reinforcement from local success history
final class ErrorAnalyzer {
	struct ExecutionContext {
		let workingDirectory: String?
		let shell: String?
		let host: String?
	}
	
	struct CommandResult {
		let exitCode: Int32
		let stdout: String
		let stderr: String
	}
	
	enum ErrorType: String {
		case permissionDenied
		case commandNotFound
		case missingPackage
		case networkIssue
		case syntaxError
		case unknown
	}
	
	struct FixSuggestion {
		let title: String          // concise description of the fix
		let command: String        // the concrete fix command (if applicable)
		let explanation: String    // why this fix is suggested
		let confidence: Double     // 0.0~1.0
	}
	
	struct Analysis {
		let errorType: ErrorType
		let explanation: String
		let suggestions: [FixSuggestion]
	}
	
	/// Analyze a failed command execution and propose fixes.
	/// - Parameters:
	///   - command: Original command string.
	///   - result: Execution result with stderr and exit code.
	///   - context: Minimal context for better classification.
	/// - Returns: `Analysis` describing the error and ordered fix suggestions.
	func analyze(command: String, result: CommandResult, context: ExecutionContext?) async -> Analysis {
		// Logic (not implemented):
		// 1. Early return if exitCode == 0 (no error).
		// 2. Classify error using patterns on stderr (ENOENT, permission, apt/yum/pip hints, etc.).
		// 3. Build small context prompt and query AI for suggestions if pattern is inconclusive.
		// 4. Merge rule-based and AI suggestions, deduplicate, score, and sort.
		// 5. Return Analysis with top-N suggestions and rationale.
		return Analysis(
			errorType: .unknown,
			explanation: "stub",
			suggestions: []
		)
	}
}
