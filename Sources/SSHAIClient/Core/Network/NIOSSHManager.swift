import Foundation
import NIO
import NIOCore
import NIOSSH

// MARK: - Host Key Validation (accept all - for development/testing only)

private final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}

// MARK: - Authentication Delegate (password only, minimal viable)

private final class PasswordAuthenticationDelegate: NIOSSHClientUserAuthenticationDelegate {
    let username: String
    let password: String

    init(username: String, password: String) {
        self.username = username
        self.password = password
    }

    public func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        if availableMethods.contains(.password) {
            let offer = NIOSSHUserAuthenticationOffer(
                username: username,
                serviceName: "",
                offer: .password(.init(password: password))
            )
            nextChallengePromise.succeed(offer)
        } else {
            nextChallengePromise.succeed(nil)
        }
    }
}

// MARK: - Command Execution Handler

private final class ExecHandler: ChannelDuplexHandler, @unchecked Sendable {
    typealias InboundIn = SSHChannelData
    typealias InboundOut = Never
    typealias OutboundIn = Never
    typealias OutboundOut = SSHChannelData

    private let promise: EventLoopPromise<CommandResult>
    private let command: String
    private var stdoutBuffer = ByteBuffer()
    private var stderrBuffer = ByteBuffer()
    private var exitCode: Int32 = -1
    private let startTime = Date()
    private var isCompleted = false

    init(command: String, promise: EventLoopPromise<CommandResult>) {
        self.command = command
        self.promise = promise
    }

    func handlerAdded(context: ChannelHandlerContext) {
        _ = context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true)
    }

    func channelActive(context: ChannelHandlerContext) {
        // Send exec request when the child channel becomes active
        let exec = SSHChannelRequestEvent.ExecRequest(command: command, wantReply: true)
        context.triggerUserOutboundEvent(exec, promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let message = self.unwrapInboundIn(data)
        guard case .byteBuffer(var bytes) = message.data else {
            return
        }
        switch message.type {
        case .channel:
            stdoutBuffer.writeBuffer(&bytes)
        case .stdErr:
            stderrBuffer.writeBuffer(&bytes)
        default:
            break
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let exit = event as? SSHChannelRequestEvent.ExitStatus {
            self.exitCode = Int32(exit.exitStatus)
        }
        context.fireUserInboundEventTriggered(event)
    }

    func channelInactive(context: ChannelHandlerContext) {
        completePromise()
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        if !isCompleted {
            promise.fail(error)
            isCompleted = true
        }
        context.close(promise: nil)
    }
    
    func handlerRemoved(context: ChannelHandlerContext) {
        completePromise()
    }
    
    private func completePromise() {
        guard !isCompleted else { return }
        isCompleted = true
        
        let result = CommandResult(
            exitCode: exitCode,
            stdout: String(buffer: stdoutBuffer),
            stderr: String(buffer: stderrBuffer),
            startedAt: startTime,
            finishedAt: Date()
        )
        promise.succeed(result)
    }
}

/// An implementation of `SSHManaging` that uses SwiftNIO SSH directly.
/// This provides full control over SSH connections while maintaining compatibility with our protocol.
public actor NIOSSHManager: SSHManaging {
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private var activeConnections: [UUID: Channel] = [:]

    public func connect(config: SSHConfig) async throws -> UUID {
        // MVP: support password only; key auth can be added later.
        guard case .password(let pwd) = config.authentication else {
            throw SSHError.authenticationFailed
        }
        guard !pwd.isEmpty else {
            throw SSHError.authenticationFailed
        }
        let userAuth = PasswordAuthenticationDelegate(username: config.username, password: pwd)
        let clientConfig = SSHClientConfiguration(userAuthDelegate: userAuth, serverAuthDelegate: AcceptAllHostKeysDelegate())

        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHandler(
                    NIOSSHHandler(
                        role: .client(clientConfig),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: { _, _ in
                            channel.eventLoop.makeSucceededFuture(())
                        }
                    )
                )
            }

        do {
            let ch = try await bootstrap.connect(host: config.host, port: config.port).get()
            // No need to explicitly wait for auth; NIOSSHHandler will buffer until ready.
            let id = UUID()
            activeConnections[id] = ch
            return id
        } catch {
            throw SSHError.connectionFailed(underlying: error)
        }
    }

    public func execute(connectionId: UUID, request: CommandRequest) async throws -> CommandResult {
        guard let channel = activeConnections[connectionId] else { throw SSHError.connectionNotFound }
        let promise = channel.eventLoop.makePromise(of: CommandResult.self)
        let wrapped = Self.wrapAsLoginInteractiveShell(command: request.command)
        let execHandler = ExecHandler(command: wrapped, promise: promise)

        let childFuture: EventLoopFuture<Channel> = channel.eventLoop.flatSubmit {
            do {
                let ssh = try channel.pipeline.syncOperations.handler(type: NIOSSHHandler.self)
                let p = channel.eventLoop.makePromise(of: Channel.self)
                ssh.createChannel(p) { child, type in
                    guard type == .session else { return child.eventLoop.makeFailedFuture(SSHError.executionFailed(underlying: nil)) }
                    return child.pipeline.addHandler(execHandler)
                }
                return p.futureResult
            } catch {
                return channel.eventLoop.makeFailedFuture(error)
            }
        }

        _ = try await childFuture.get()
        return try await promise.futureResult.get()
    }

    public func disconnect(connectionId: UUID) async throws {
        guard let ch = activeConnections.removeValue(forKey: connectionId) else { throw SSHError.connectionNotFound }
        try await ch.close().get()
    }
    
    // Wrap the user command to ensure login + interactive shell semantics so PATH and user env are loaded.
    private static func wrapAsLoginInteractiveShell(command: String) -> String {
        // Safely single-quote the payload for POSIX shells
        let escaped = command.replacingOccurrences(of: "'", with: "'\"'\"'")
        // Prefer the user's shell from $SHELL if present; fall back to zsh, then bash, then sh.
        // -l: login shell (loads .zprofile/.profile)
        // -i: interactive shell (loads .zshrc/.bashrc)
        // -c: run the provided command string
        let script = "if [ -n \"$SHELL\" ]; then exec \"$SHELL\" -lic '\(escaped)'; " +
                     "elif command -v zsh >/dev/null 2>&1; then exec zsh -lic '\(escaped)'; " +
                     "elif command -v bash >/dev/null 2>&1; then exec bash -lic '\(escaped)'; " +
                     "else exec sh -lc '\(escaped)'; fi"
        return script
    }

    deinit {
        try? group.syncShutdownGracefully()
    }
}
