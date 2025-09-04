import Foundation

// MARK: - Public Data Structures

/// Strongly typed connection configuration
public struct SSHConfig: Equatable, Sendable {
    public let host: String
    public let port: Int
    public let username: String
    public let authentication: Authentication
    public let timeoutSeconds: TimeInterval

    public init(host: String, port: Int, username: String, authentication: Authentication, timeoutSeconds: TimeInterval) {
        self.host = host
        self.port = port
        self.username = username
        self.authentication = authentication
        self.timeoutSeconds = timeoutSeconds
    }
    
    /// Supported authentication methods
    public enum Authentication: Equatable, Sendable {
        case password(String)
        case privateKey(pem: Data, passphrase: String?)
    }
}

/// Execution request containing command and optional environment context
public struct CommandRequest {
    public let command: String
    public let workingDirectory: String?
    public let environment: [String: String]?
    public let allocatePty: Bool

    public init(command: String, workingDirectory: String? = nil, environment: [String: String]? = nil, allocatePty: Bool = false) {
        self.command = command
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.allocatePty = allocatePty
    }
}

/// Execution result, modeled for auditability and downstream processing
public struct CommandResult {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public let startedAt: Date
    public let finishedAt: Date
}

/// Public error types to help the caller distinguish failure categories
public enum SSHError: Error {
    case connectionNotFound
    case connectionFailed(underlying: Error?)
    case authenticationFailed
    case executionFailed(underlying: Error?)
    case alreadyConnected
    case disconnected
}


// MARK: - Protocol Definition

/// An interface for managing SSH connections.
/// This protocol abstracts the underlying implementation of SSH connections,
/// allowing for different providers (e.g., a real SSH library, a mock for testing).
public protocol SSHManaging: Sendable {
    /// Establish an SSH connection.
    /// - Parameters:
    ///   - config: SSH target configuration including host, port, credentials, and timeout.
    /// - Returns: A UUID that identifies this connection for subsequent operations.
    /// - Throws: `SSHError.connectionFailed` or `SSHError.authenticationFailed` on failure.
    func connect(config: SSHConfig) async throws -> UUID

    /// Execute a shell command on an established connection.
    /// - Parameters:
    ///   - connectionId: UUID returned by `connect`.
    ///   - request: Command details such as command string, cwd, env, and PTY allocation.
    /// - Returns: `CommandResult` including stdout, stderr, exit code, and timing.
    /// - Throws: `SSHError.connectionNotFound`, `SSHError.executionFailed`, or `SSHError.disconnected`.
    func execute(connectionId: UUID, request: CommandRequest) async throws -> CommandResult

    /// Disconnect and clean up resources for a given connection.
    /// - Parameter connectionId: UUID returned by `connect`.
    /// - Throws: `SSHError.connectionNotFound` if the id is unknown.
    func disconnect(connectionId: UUID) async throws
}
