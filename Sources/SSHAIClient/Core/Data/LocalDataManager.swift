import Foundation

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
final class LocalDataManager {
	// MARK: - Data Models
	struct Connection: Equatable, Identifiable {
		let id: String
		let name: String
		let host: String
		let port: Int
		let username: String
		let createdAt: Date
	}
	
	struct CommandRecord: Equatable, Identifiable {
		let id: String
		let sessionId: String
		let command: String
		let stdout: String?
		let stderr: String?
		let exitCode: Int32
		let executedAt: Date
		let workingDirectory: String?
		let isAiGenerated: Bool
	}
	
	struct Script: Equatable, Identifiable {
		let id: String
		let title: String
		let language: String // shell|python|ts
		let content: String
		let createdAt: Date
		let updatedAt: Date
	}
	
	struct AiCacheEntry: Equatable, Identifiable {
		let id: String
		let inputHash: String
		let payload: Data
		let createdAt: Date
	}
	
	// MARK: - Lifecycle
	/// Initialize (open) the database, create tables if not exists, and run migrations.
	/// - Throws: Underlying DB errors when initialization/migration fails.
	func initialize() throws {
		// Logic (not implemented):
		// 1. Resolve DB file path in Documents.
		// 2. Open connection with SQLite.swift.
		// 3. Create tables if not exists.
		// 4. Run pending migrations.
		// 5. Seed built-in scripts (idempotent).
		throw NSError(domain: "LocalDataManager", code: -1)
	}
	
	// MARK: - CRUD: Connections
	func upsertConnection(_ connection: Connection) throws {
		// Insert or update connection by id.
		throw NSError(domain: "LocalDataManager", code: -1)
	}
	
	func listConnections() throws -> [Connection] {
		// Return all connections ordered by createdAt desc.
		throw NSError(domain: "LocalDataManager", code: -1)
	}
	
	func deleteConnection(id: String) throws {
		// Delete by id, cascade cleanup if needed.
		throw NSError(domain: "LocalDataManager", code: -1)
	}
	
	// MARK: - CRUD: Command History
	func appendCommand(_ record: CommandRecord) throws {
		// Append command execution record.
		throw NSError(domain: "LocalDataManager", code: -1)
	}
	
	func listCommands(sessionId: String) throws -> [CommandRecord] {
		// Return all commands in a session, ordered by executedAt asc.
		throw NSError(domain: "LocalDataManager", code: -1)
	}
	
	// MARK: - CRUD: Scripts
	func upsertScript(_ script: Script) throws {
		// Insert or update a script document.
		throw NSError(domain: "LocalDataManager", code: -1)
	}
	
	func listScripts(language: String?) throws -> [Script] {
		// Optionally filter by language.
		throw NSError(domain: "LocalDataManager", code: -1)
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
