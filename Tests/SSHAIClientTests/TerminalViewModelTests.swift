import XCTest
@testable import SSHAIClient

// A mock implementation of the SSHManaging protocol for testing purposes.
class MockSSHManager: SSHManaging, @unchecked Sendable {
    
    var shouldConnectSuccessfully: Bool
    var connectCallCount = 0
    var lastConnectedConfig: SSHConfig?
    
    init(shouldConnectSuccessfully: Bool) {
        self.shouldConnectSuccessfully = shouldConnectSuccessfully
    }
    
    func connect(config: SSHConfig) async throws -> UUID {
        connectCallCount += 1
        lastConnectedConfig = config
        
        if shouldConnectSuccessfully {
            return UUID()
        } else {
            throw SSHError.connectionFailed(underlying: nil)
        }
    }
    
    func execute(connectionId: UUID, request: CommandRequest) async throws -> CommandResult {
        // Not needed for this test, but required by the protocol.
        fatalError("execute should not be called in this test scenario")
    }
    
    func disconnect(connectionId: UUID) async throws {
        // Not needed for this test, but required by the protocol.
        fatalError("disconnect should not be called in this test scenario")
    }
}

final class TerminalViewModelTests: XCTestCase {

    var mockSSHManager: MockSSHManager!
    // We will use dummy objects for other dependencies for now.
    // In a real-world scenario, these would also be mocked.
    var dummyClassifier: SimpleInputClassifier!
    var dummyGenerator: CommandGenerator!
    var dummyDataManager: LocalDataManager!
    
    var viewModel: TerminalViewModel!

    override func setUp() {
        super.setUp()
        // Dependencies can be initialized here for each test.
        dummyClassifier = SimpleInputClassifier()
        dummyGenerator = CommandGenerator()
        dummyDataManager = LocalDataManager()
    }
    
    @MainActor
    func testConnect_WhenSucceeds_UpdatesState() async {
        // Arrange
        mockSSHManager = MockSSHManager(shouldConnectSuccessfully: true)
        viewModel = TerminalViewModel(
            ssh: mockSSHManager,
            classifier: dummyClassifier,
            generator: dummyGenerator,
            data: dummyDataManager
        )
        let testConfig = SSHConfig(host: "localhost", port: 22, username: "test", authentication: .password("password"), timeoutSeconds: 5)
        
        // Act
        let result = await viewModel.connect(config: testConfig)
        
        // Assert
        XCTAssertTrue(result, "Connect method should return true on success")
        XCTAssertTrue(viewModel.isConnected, "ViewModel's isConnected property should be true after a successful connection")
        XCTAssertNotNil(viewModel.currentConnectionId, "ViewModel should have a valid connection ID after connecting")
        XCTAssertEqual(mockSSHManager.connectCallCount, 1, "The ssh manager's connect method should be called exactly once")
        XCTAssertEqual(mockSSHManager.lastConnectedConfig, testConfig, "The ssh manager should be called with the correct config")
    }
    
    @MainActor
    func testConnect_WhenFails_UpdatesState() async {
        // Arrange
        mockSSHManager = MockSSHManager(shouldConnectSuccessfully: false)
        viewModel = TerminalViewModel(
            ssh: mockSSHManager,
            classifier: dummyClassifier,
            generator: dummyGenerator,
            data: dummyDataManager
        )
        let testConfig = SSHConfig(host: "localhost", port: 22, username: "test", authentication: .password("password"), timeoutSeconds: 5)
        
        // Act
        let result = await viewModel.connect(config: testConfig)
        
        // Assert
        XCTAssertFalse(result, "Connect method should return false on failure")
        XCTAssertFalse(viewModel.isConnected, "ViewModel's isConnected property should remain false after a failed connection")
        XCTAssertNil(viewModel.currentConnectionId, "ViewModel should not have a connection ID after a failed connection")
        XCTAssertEqual(mockSSHManager.connectCallCount, 1, "The ssh manager's connect method should still be called once")
    }
}
