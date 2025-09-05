import SwiftUI

@available(macOS 11.0, *)
public struct ContentView: View {
    @StateObject private var viewModel: TerminalViewModel

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

            Divider()

            // Main terminal area
            TerminalView(viewModel: viewModel)
        }
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
