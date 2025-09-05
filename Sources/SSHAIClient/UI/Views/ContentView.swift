import SwiftUI
import Foundation

@available(macOS 11.0, *)
public struct ContentView: View {
    @StateObject private var viewModel: TerminalViewModel
    @StateObject private var configManager = SSHConfigManager.shared
    @State private var showSettings = false
    @State private var connectionError: String? = nil
    @State private var isConnecting = false

    public init() {
        // 使用真实的SSH管理器，不再区分Mock和Real
        let vm = TerminalViewModel(
            ssh: NIOSSHManager(),
            classifier: SimpleInputClassifier(),
            generator: CommandGenerator(),
            data: LocalDataManager()
        )
        _viewModel = StateObject(wrappedValue: vm)
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                // Connection Info
                HStack(spacing: 8) {
                    Circle()
                        .fill(viewModel.isConnected ? Color.green : (isConnecting ? Color.orange : Color.gray))
                        .frame(width: 8, height: 8)
                    
                    if isConnecting {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                    }
                    
                    Text(connectionStatusText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Actions
                HStack(spacing: 12) {
                    if viewModel.isConnected {
                        Button("Disconnect") {
                            Task { await disconnect() }
                        }
                        .controlSize(.small)
                    } else if !isConnecting {
                        Button("Connect") {
                            Task { await connect() }
                        }
                        .controlSize(.small)
                        .keyboardShortcut("k", modifiers: .command)
                    }
                    
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .help("Settings (⌘,)")
                    .keyboardShortcut(",", modifiers: .command)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Error Alert
            if let error = connectionError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.system(size: 11))
                        .lineLimit(2)
                    Spacer()
                    Button("Dismiss") {
                        connectionError = nil
                    }
                    .controlSize(.mini)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                
                Divider()
            }
            
            // Main terminal area
            TerminalView(viewModel: viewModel)
        }
        .background(Color(PlatformColor.controlBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
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
            
            // Auto-connect if configured
            if configManager.autoConnect && !viewModel.isConnected {
                Task {
                    await connect()
                }
            }
        }
    }
    
    private var connectionStatusText: String {
        if isConnecting {
            return "Connecting to \(configManager.host)..."
        } else if viewModel.isConnected {
            return "\(configManager.username)@\(configManager.host):\(configManager.port)"
        } else {
            return "Not connected"
        }
    }
    
    @MainActor
    private func connect() async {
        // 验证配置
        let validation = configManager.isConfigValid()
        guard validation.valid else {
            connectionError = validation.message
            return
        }
        
        isConnecting = true
        connectionError = nil
        
        // 获取当前配置
        let config = configManager.currentConfig()
        
        do {
            if let err = await viewModel.connect(config: config) {
                connectionError = err.localizedDescription
            } else {
                // 成功连接，添加到最近使用
                configManager.addToRecentHosts(config.host)
            }
        }
        
        isConnecting = false
    }
    
    @MainActor
    private func disconnect() async {
        await viewModel.disconnect()
        connectionError = nil
    }
}
