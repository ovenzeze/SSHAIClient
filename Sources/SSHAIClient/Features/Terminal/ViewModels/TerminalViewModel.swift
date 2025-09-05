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
public final class TerminalViewModel: ObservableObject {
	@Published public private(set) var currentConnectionId: UUID?
	@Published public private(set) var isConnected: Bool = false
	@Published public private(set) var currentSuggestion: CommandSuggestion? // AI生成的完整建议
	@Published public private(set) var commandHistory: [CommandHistoryItem] = []
	
	// Sanitize terminal control sequences (OSC 1337, ANSI CSI, etc.) before showing in UI
	private func sanitizeOutput(_ text: String) -> String {
		var result = text
		// iTerm2/OSC sequences like: ESC ] 1337 ; ... BEL  or  ESC ] 1337 ; ... ESC \\
		let oscPattern = "\u{001B}\\][0-9]{1,4};.*?(?:\u{0007}|\u{001B}\\\\)"
		// General ANSI CSI sequences like: ESC [ 0;31m or other control codes ending in @-~
		let csiPattern = "\u{001B}\\[[0-9;?]*[ -/]*[@-~]"
		result = result.replacingOccurrences(of: oscPattern, with: "", options: .regularExpression)
		result = result.replacingOccurrences(of: csiPattern, with: "", options: .regularExpression)
		return result
	}
	
	private let ssh: SSHManaging
	private let classifier: SimpleInputClassifier
	private let generator: CommandGenerator
	private let data: LocalDataManager
	
	public init(
		ssh: SSHManaging,
		classifier: SimpleInputClassifier,
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
    public func connect(config: SSHConfig) async -> Error? {
        do {
            let connectionId = try await ssh.connect(config: config)
            self.currentConnectionId = connectionId
            self.isConnected = true
            return nil
        } catch {
            self.currentConnectionId = nil
            self.isConnected = false
            print("SSH connection failed: \(error)")
            return error
        }
    }
	
	/// Handle user input - 分类后直接执行或生成AI建议
	/// - Parameter input: Raw text from the input bar.
	@MainActor
	public func handleAutoInput(_ input: String) async {
		guard isConnected, currentConnectionId != nil else {
			print("No active connection")
			return
		}
		
		// 使用新的简单分类器
		let classification = classifier.classify(input)
		print("Classification: \(classification.type), reason: \(classification.reason)")
		
		switch classification.type {
		case .command:
			// 直接执行命令
			await executeCommand(input)
			
		case .naturalLanguage:
			// 生成AI建议
			await generateCommandSuggestion(for: input)
		}
	}
	
	/// Execute a direct shell command.
	/// - Parameter command: The exact command to run.
	@MainActor
	public func executeCommand(_ command: String) async {
		guard isConnected, let connectionId = currentConnectionId else {
			print("No active connection")
			// Add error to history
			let item = CommandHistoryItem(
				command: command,
				output: "Error: No active SSH connection",
				error: nil,
				exitCode: -1,
				timestamp: Date()
			)
			commandHistory.append(item)
			return
		}
		
		do {
			let request = CommandRequest(
				command: command,
				workingDirectory: nil, // Let server decide
				environment: nil,
				allocatePty: false // Simple command execution
			)
			
			let result = try await ssh.execute(connectionId: connectionId, request: request)
			
			// Clear any current suggestion since we executed a command
			self.currentSuggestion = nil
			
			// Sanitize outputs before presenting
			let cleanStdout = sanitizeOutput(result.stdout)
			let cleanStderr = sanitizeOutput(result.stderr)
			
			// Add to command history with output
			let item = CommandHistoryItem(
				command: command,
				output: cleanStdout,
				error: cleanStderr.isEmpty ? nil : cleanStderr,
				exitCode: result.exitCode,
				timestamp: Date()
			)
			commandHistory.append(item)
			
			// Also log for debugging
			print("Command executed: \(command)")
			print("Exit code: \(result.exitCode)")
			if !result.stdout.isEmpty {
				print("Stdout: \(result.stdout)")
			}
			if !result.stderr.isEmpty {
				print("Stderr: \(result.stderr)")
			}
			
		} catch {
			print("Command execution failed: \(error)")
			// Add error to history (sanitize message just in case)
			let cleanError = sanitizeOutput("Execution failed: \(error.localizedDescription)")
			let item = CommandHistoryItem(
				command: command,
				output: "",
				error: cleanError,
				exitCode: -1,
				timestamp: Date()
			)
			commandHistory.append(item)
		}
	}
	
	/// 生成AI命令建议
	@MainActor
	public func generateCommandSuggestion(for query: String) async {
		do {
			let context = GenerationContext(
				host: HostInfo(osName: "Darwin", osVersion: "14.1", architecture: "x86_64"),
				shell: ShellInfo(name: "zsh"),
				workingDirectory: "/Users/demo/workspace"
			)
			
			let suggestion = try await generator.generate(query: query, context: context)
			self.currentSuggestion = suggestion
			print("AI suggestion: \(suggestion.command)")
		} catch {
			print("Command generation failed: \(error)")
			self.currentSuggestion = nil
		}
	}
	
	/// 执行AI推荐的命令
	@MainActor
	public func executeSuggestion() async {
		guard let suggestion = currentSuggestion else {
			print("No suggestion to execute")
			return
		}
		
		await executeCommand(suggestion.command)
		self.currentSuggestion = nil // 清除建议
	}
	
	/// Disconnect from the current SSH session
	@MainActor
	public func disconnect() async {
		guard let connectionId = currentConnectionId else {
			return
		}
		
		do {
			try await ssh.disconnect(connectionId: connectionId)
		} catch {
			print("Disconnect failed: \(error)")
		}
		
		self.currentConnectionId = nil
		self.isConnected = false
		self.currentSuggestion = nil
	}
}
