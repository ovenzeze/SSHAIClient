import Foundation

/// A mock SSH manager for development and testing purposes.
/// This allows the app to run without actual SSH connections.
public actor MockSSHManager: SSHManaging {
    
    private var connections: [UUID: MockConnection] = [:]
    
    public func connect(config: SSHConfig) async throws -> UUID {
        // Simulate connection delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        let connectionId = UUID()
        let connection = MockConnection(config: config)
        connections[connectionId] = connection
        
        print("Mock SSH connected to \(config.username)@\(config.host):\(config.port)")
        return connectionId
    }
    
    public func execute(connectionId: UUID, request: CommandRequest) async throws -> CommandResult {
        guard connections[connectionId] != nil else {
            throw SSHError.connectionNotFound
        }
        
        // Simulate execution delay
        try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        
        let startTime = Date()
        let result = simulateCommandExecution(request.command)
        let endTime = Date()
        
        print("Mock SSH executed: \(request.command)")
        print("Mock result: \(result.stdout)")
        
        return CommandResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr,
            startedAt: startTime,
            finishedAt: endTime
        )
    }
    
    public func disconnect(connectionId: UUID) async throws {
        guard connections[connectionId] != nil else {
            throw SSHError.connectionNotFound
        }
        
        connections.removeValue(forKey: connectionId)
        print("Mock SSH disconnected")
    }
    
    // MARK: - Private
    
    private struct MockConnection {
        let config: SSHConfig
        let connectedAt: Date = Date()
    }
    
    private func simulateCommandExecution(_ command: String) -> (exitCode: Int32, stdout: String, stderr: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simulate common commands
        switch trimmedCommand {
        case "ls", "ls -la":
            return (0, "total 8\ndrwxr-xr-x  3 user  staff   96 Dec 14 10:30 .\ndrwxr-xr-x  5 user  staff  160 Dec 14 10:29 ..\n-rw-r--r--  1 user  staff   12 Dec 14 10:30 test.txt", "")
            
        case "pwd":
            return (0, "/Users/demo/workspace", "")
            
        case "whoami":
            return (0, "demo", "")
            
        case "date":
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            formatter.timeStyle = .medium
            return (0, formatter.string(from: Date()), "")
            
        case let cmd where cmd.hasPrefix("echo "):
            let text = String(cmd.dropFirst(5))
            return (0, text, "")
            
        case "ps aux":
            return (0, "USER       PID  %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND\ndemo      1234   0.0  0.1  12345  6789 pts/0    S    10:30   0:00 bash\ndemo      5678   0.0  0.0   4321  2109 pts/0    R    10:31   0:00 ps aux", "")
            
        case "uname -a":
            return (0, "Darwin demo.local 23.1.0 Darwin Kernel Version 23.1.0 x86_64", "")
            
        case "sw_vers":
            return (0, "ProductName:\tmacOS\nProductVersion:\t14.1\nBuildVersion:\t23B74", "")
            
        case let cmd where cmd.hasPrefix("cd "):
            return (0, "", "")
            
        default:
            if trimmedCommand.hasPrefix("#") {
                // Comment or disabled command
                return (0, "Command disabled or commented out", "")
            } else {
                // Unknown command
                return (127, "", "bash: \(trimmedCommand): command not found")
            }
        }
    }
}
