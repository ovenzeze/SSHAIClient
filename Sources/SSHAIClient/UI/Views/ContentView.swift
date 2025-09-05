import SwiftUI

@available(macOS 11.0, *)
public struct ContentView: View {
    @StateObject private var viewModel: TerminalViewModel
    @StateObject private var connVM = ConnectionManagerViewModel()
    @State private var showSettings = false
    @State private var showSidebar = true

    public init() {
        // Initialize dependencies
        let sshManager = MockSSHManager()
        let classifier = SimpleInputClassifier()
        let generator = CommandGenerator()
        let dataManager = LocalDataManager()

        self._viewModel = StateObject(wrappedValue: TerminalViewModel(
            ssh: sshManager,
            classifier: classifier,
            generator: generator,
            data: dataManager
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header with connection status
            HeaderView(viewModel: viewModel)
                .overlay(
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Button(action: { withAnimation { showSidebar.toggle() } }) {
                                Image(systemName: showSidebar ? "sidebar.leading" : "sidebar.left")
                            }
                            .help("Toggle sidebar")
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                            .help("Settings")
                        }
                        .padding(.trailing, 8)
                    }
                )

            Divider()

            // Main area with optional sidebar
            HStack(spacing: 0) {
                if showSidebar {
                    ConnectionManager(viewModel: connVM) { conn in
                        connect(from: conn)
                    }
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 320)
                    .background(Color(PlatformColor.windowBackgroundColor))
                }

                Divider()

                // Terminal Area
                TerminalView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .background(Color(PlatformColor.controlBackgroundColor))
        .onAppear {
            // Ensure window activation on macOS
            #if os(macOS)
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                    window.level = .normal
                    window.makeFirstResponder(nil)
                    // Force window to become key window
                    window.makeKey()
                }
            }
            #endif
        }
    }

    private func connect(from conn: SSHConnection) {
        let cfg = SSHConfig(host: conn.host, port: conn.port, username: conn.username, authentication: .password(""), timeoutSeconds: 30)
        Task { _ = await viewModel.connect(config: cfg) }
    }
}

@available(macOS 11.0, *)
public struct HeaderView: View {
    @ObservedObject var viewModel: TerminalViewModel

    public init(viewModel: TerminalViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack {
            // Connection status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(viewModel.isConnected ? "Connected" : "Disconnected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Connect button
            if !viewModel.isConnected {
                Button("Connect") {
                    Task {
                        await connectToDemo()
                    }
                }
                .modifier(BorderedProminentButtonModifier())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(PlatformColor.windowBackgroundColor))
    }

    private func connectToDemo() async {
        // Demo connection - in a real app this would show a connection dialog
        let config = SSHConfig(
            host: "demo.host",
            port: 22,
            username: "demo",
            authentication: .password("demo"),
            timeoutSeconds: 30
        )

        let _ = await viewModel.connect(config: config)
    }
}
