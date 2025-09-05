import XCTest
@testable import SSHAIClient

class SSHAIClientPersistenceTests: XCTestCase {

    var dataManager: LocalDataManager!

    override func setUpWithError() throws {
        dataManager = LocalDataManager()
        try dataManager.initializeForTesting()
    }

    override func tearDownWithError() throws {
        dataManager = nil
    }

    func testConnectionCRUD_withEncryption() throws {
        let connection = SSHConnection(id: "1", name: "test-encrypted", host: "localhost.encrypted", port: 2222, username: "testuser-encrypted", createdAt: Date())
        try dataManager.upsertConnection(connection)

        let connections = try dataManager.listConnections()
        XCTAssertEqual(connections.count, 1)
        let fetchedConnection = connections.first!
        
        XCTAssertEqual(fetchedConnection.name, "test-encrypted")
        XCTAssertEqual(fetchedConnection.host, "localhost.encrypted")
        XCTAssertEqual(fetchedConnection.username, "testuser-encrypted")

        try dataManager.deleteConnection(id: "1")
        let connectionsAfterDelete = try dataManager.listConnections()
        XCTAssertEqual(connectionsAfterDelete.count, 0)
    }
    
    func testCommandHistoryCRUD() throws {
        let command = CommandRecord(id: "cmd1", sessionId: "session1", command: "ls -la", stdout: "total 0", stderr: nil, exitCode: 0, executedAt: Date(), workingDirectory: "/tmp", isAiGenerated: false)
        try dataManager.appendCommand(command)
        
        let commands = try dataManager.listCommands(sessionId: "session1")
        XCTAssertEqual(commands.count, 1)
        XCTAssertEqual(commands.first?.command, "ls -la")
    }

    func testScriptsCRUD() throws {
        let now = Date()
        let s = Script(id: "s1", title: "List Files", language: "shell", content: "ls -la", createdAt: now, updatedAt: now)
        try dataManager.upsertScript(s)

        var scripts = try dataManager.listScripts(language: nil)
        XCTAssertEqual(scripts.count, 1)
        XCTAssertEqual(scripts.first?.title, "List Files")

        scripts = try dataManager.listScripts(language: "shell")
        XCTAssertEqual(scripts.count, 1)

        try dataManager.deleteScript(id: "s1")
        scripts = try dataManager.listScripts(language: nil)
        XCTAssertEqual(scripts.count, 0)
    }
}
