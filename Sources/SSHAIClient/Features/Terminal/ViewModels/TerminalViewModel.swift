import Foundation

/// TerminalViewModel coordinates terminal I/O, auto mode routing, AI suggestions,
/// and command execution workflows. It is designed to be UI-agnostic and testable.
///
/// Responsibilities:
/// - Maintain current connection state and session id
/// - Route input via HybridIntentClassifier in Auto mode
/// - Request CommandGenerator for NL2CLI suggestions
/// - Execute commands via SSHConnectionManager and persist history via LocalDataManager
/// - Surface AI suggestion cards and error analyses to the UI
final class TerminalViewModel: ObservableObject {
	@Published private(set) var currentConnectionId: UUID?
	@Published private(set) var isConnected: Bool = false
	@Published private(set) var currentSuggestion: String? // preview text only (UI formats)
	
	private let ssh: SSHManaging
	private let classifier: HybridIntentClassifier
	private let generator: CommandGenerator
	private let data: LocalDataManager
	
	init(
		ssh: SSHManaging,
		classifier: HybridIntentClassifier,
		generator: CommandGenerator,
		data: LocalDataManager
	) {
		self.ssh = ssh
		self.classifier = classifier
		self.generator = generator
		self.data = data
	}
	
	/// Connect to a target host.
	/// - Parameter config: SSH config containing host/port/user/auth.
	/// - Returns: Bool indicating immediate success of the connection attempt.
	@MainActor
	func connect(config: SSHConfig) async -> Bool {
		do {
			let connectionId = try await ssh.connect(config: config)
			self.currentConnectionId = connectionId
			self.isConnected = true
			return true
		} catch {
			self.currentConnectionId = nil
			self.isConnected = false
			// Optionally, we could have a @Published error property to show alerts.
			// For now, just logging it.
			print("SSH connection failed: \(error)")
			return false
		}
	}
	
	/// Handle user input in Auto mode.
	/// - Parameter input: Raw text from the input bar.
	@MainActor
	func handleAutoInput(_ input: String) async {
		// Logic (not implemented):
		// 1. Build terminal context
		// 2. Classify intent
		// 3. If aiQuery -> request CommandGenerator to produce suggestion; set currentSuggestion
		// 4. If command -> forward to executeCommand
	}
	
	/// Execute a direct shell command.
	/// - Parameter command: The exact command to run.
	@MainActor
	func executeCommand(_ command: String) async {
		// Logic (not implemented):
		// 1. Build request and call ssh.execute
		// 2. Append history via data.appendCommand
		// 3. If error -> produce ErrorAnalyzer output and expose to UI
	}
}
