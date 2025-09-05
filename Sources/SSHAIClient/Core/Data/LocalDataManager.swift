import Foundation
import SQLite
import CryptoKit

// Avoid Expression name collision with Swift 6
private typealias Expression = SQLite.Expression

// MARK: - Public Data Models
public struct SSHConnection: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let host: String
    public let port: Int
    public let username: String
    public let createdAt: Date
}

public struct CommandRecord: Equatable, Identifiable {
    public let id: String
    public let sessionId: String
    public let command: String
    public let stdout: String?
    public let stderr: String?
    public let exitCode: Int
    public let executedAt: Date
    public let workingDirectory: String?
    public let isAiGenerated: Bool
}

public struct Script: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let language: String // shell|python|ts
    public let content: String
    public let createdAt: Date
    public let updatedAt: Date
}

public struct AiCacheEntry: Equatable, Identifiable {
    public let id: String
    public let inputHash: String
    public let payload: Data
    public let createdAt: Date
}

/// LocalDataManager encapsulates SQLite-backed persistence for the app.
/// It creates and migrates tables, and provides typed CRUD operations for:
/// - Connections
/// - Sessions & command history
/// - Scripts
/// - AI response cache
///
/// Notes:
/// - This is a stub defining contracts and data models, without DB implementation.
/// - Real implementation should use SQLite.swift with proper error handling and migrations.
public final class LocalDataManager: @unchecked Sendable {
    
    private var db: SQLite.Connection?

    // MARK: - Table Definitions
    private let connections = Table("connections")
    private let commandHistory = Table("command_history")
    private let scripts = Table("scripts")
    private let aiSuggestions = Table("ai_suggestions")

    // MARK: - Column Definitions
    private let id = Expression<String>("id")
    private let name = Expression<String>("name")
    private let host = Expression<String>("host")
    private let port = Expression<Int>("port")
    private let username = Expression<String>("username")
    private let createdAt = Expression<Date>("createdAt")
    
    private let sessionId = Expression<String>("sessionId")
    private let command = Expression<String>("command")
    private let stdout = Expression<String?>("stdout")
    private let stderr = Expression<String?>("stderr")
    private let exitCode = Expression<Int>("exitCode")
    private let executedAt = Expression<Date>("executedAt")
    private let workingDirectory = Expression<String?>("workingDirectory")
    private let isAiGenerated = Expression<Bool>("isAiGenerated")
    
    private let title = Expression<String>("title")
    private let language = Expression<String>("language")
    private let content = Expression<String>("content")
    private let updatedAt = Expression<Date>("updatedAt")

    private let query = Expression<String>("query")
    private let suggestion = Expression<String>("suggestion")
    private let confidence = Expression<Double>("confidence")
    private let accepted = Expression<Bool>("accepted")
    
    // MARK: - Crypto helpers
    private func encryptToB64(_ plaintext: String) throws -> String {
        let key = try SecureStore.getKey()
        let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key)
        guard let combined = sealed.combined else { throw NSError(domain: "LocalDataManager", code: -2) }
        return combined.base64EncodedString()
    }

    private func decryptFromB64(_ b64: String) throws -> String {
        let key = try SecureStore.getKey()
        let combined = Data(base64Encoded: b64) ?? Data()
        let box = try AES.GCM.SealedBox(combined: combined)
        let data = try AES.GCM.open(box, using: key)
        return String(decoding: data, as: UTF8.self)
    }
	
	public init() {}
	
	// MARK: - Lifecycle
	/// Initialize (open) the database, create tables if not exists, and run migrations.
	/// - Throws: Underlying DB errors when initialization/migration fails.
	public func initialize() throws {
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dbDir = appSupportURL.appendingPathComponent("SSHAIClient")
        try fileManager.createDirectory(at: dbDir, withIntermediateDirectories: true, attributes: nil)
        let dbURL = dbDir.appendingPathComponent("sshaiclient.sqlite3")
        
        db = try SQLite.Connection(dbURL.path)
        
        try db?.transaction {
            try MigrationManager.migrate(db: db!)
            try createTables()
        }
	}

    public func initializeForTesting() throws {
        db = try SQLite.Connection(.inMemory)
        try db?.transaction {
            try MigrationManager.migrate(db: db!)
            try createTables()
        }
    }
    
    private func createTables() throws {
        try db?.run(connections.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(name)
            t.column(host)
            t.column(port)
            t.column(username)
            t.column(createdAt)
        })
        
        try db?.run(commandHistory.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(sessionId)
            t.column(command)
            t.column(stdout)
            t.column(stderr)
            t.column(exitCode)
            t.column(executedAt)
            t.column(workingDirectory)
            t.column(isAiGenerated)
        })
        
        try db?.run(scripts.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(title)
            t.column(language)
            t.column(content)
            t.column(createdAt)
            t.column(updatedAt)
        })
        
        try db?.run(aiSuggestions.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(query)
            t.column(suggestion)
            t.column(confidence)
            t.column(accepted)
        })
    }
	
	// MARK: - CRUD: Connections
	public func upsertConnection(_ connection: SSHConnection) throws {
        let encHost = try encryptToB64(connection.host)
        let encUser = try encryptToB64(connection.username)
        try db?.run(connections.insert(or: .replace,
            id <- connection.id,
            name <- connection.name,
            host <- encHost,
            port <- connection.port,
            username <- encUser,
            createdAt <- connection.createdAt
        ))
	}
	
	public func listConnections() throws -> [SSHConnection] {
        let query = connections.order(createdAt.desc)
        return try db?.prepare(query).map { row in
            let hostB64 = try row.get(host)
            let userB64 = try row.get(username)
            return SSHConnection(
                id: try row.get(id),
                name: try row.get(name),
                host: try decryptFromB64(hostB64),
                port: try row.get(port),
                username: try decryptFromB64(userB64),
                createdAt: try row.get(createdAt)
            )
        } ?? []
	}
	
	public func deleteConnection(id: String) throws {
        let q = connections.filter(self.id == id)
        try db?.run(q.delete())
	}
	
	// MARK: - CRUD: Command History
	public func appendCommand(_ record: CommandRecord) throws {
        try db?.run(commandHistory.insert(
            id <- record.id,
            sessionId <- record.sessionId,
            command <- record.command,
            stdout <- record.stdout,
            stderr <- record.stderr,
            exitCode <- record.exitCode,
            executedAt <- record.executedAt,
            workingDirectory <- record.workingDirectory,
            isAiGenerated <- record.isAiGenerated
        ))
	}
	
	public func listCommands(sessionId: String) throws -> [CommandRecord] {
        let q = commandHistory.filter(self.sessionId == sessionId).order(executedAt.asc)
        return try db?.prepare(q).map { row in
            CommandRecord(
                id: try row.get(id),
                sessionId: try row.get(self.sessionId),
                command: try row.get(command),
                stdout: try row.get(stdout),
                stderr: try row.get(stderr),
                exitCode: try row.get(exitCode),
                executedAt: try row.get(executedAt),
                workingDirectory: try row.get(workingDirectory),
                isAiGenerated: try row.get(isAiGenerated)
            )
        } ?? []
	}
	
	// MARK: - CRUD: Scripts
	public func upsertScript(_ script: Script) throws {
        try db?.run(scripts.insert(or: .replace,
            id <- script.id,
            title <- script.title,
            language <- script.language,
            content <- script.content,
            createdAt <- script.createdAt,
            updatedAt <- script.updatedAt
        ))
	}
	
	public func listScripts(language: String?) throws -> [Script] {
        var q = scripts.order(updatedAt.desc)
        if let lang = language {
            q = q.filter(self.language == lang)
        }
        return try db?.prepare(q).map { row in
            Script(
                id: try row.get(id),
                title: try row.get(title),
                language: try row.get(self.language),
                content: try row.get(content),
                createdAt: try row.get(createdAt),
                updatedAt: try row.get(updatedAt)
            )
        } ?? []
	}

    public func deleteScript(id scriptId: String) throws {
        let q = scripts.filter(id == scriptId)
        try db?.run(q.delete())
    }
	
	// MARK: - AI Cache
	func putCache(_ entry: AiCacheEntry) throws {
		// Insert cache entry keyed by inputHash.
		throw NSError(domain: "LocalDataManager", code: -1)
	}
	
	func getCache(inputHash: String) throws -> AiCacheEntry? {
		// Return cache entry if exists and not expired.
		throw NSError(domain: "LocalDataManager", code: -1)
	}
}

