import SwiftUI

@available(macOS 11.0, *)
public struct SettingsView: View {
    @StateObject private var configManager = SSHConfigManager.shared
    @State private var showPasswordField = false
    @State private var showPassphraseField = false
    @State private var testConnectionResult: String = ""
    @State private var isTestingConnection = false
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SSH Connection Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Settings Form
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Connection Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Connection", systemImage: "network")
                                .font(.headline)
                            
                            HStack(alignment: .top) {
                                Text("Host:")
                                    .frame(width: 100, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("localhost", text: $configManager.host)
                                        .textFieldStyle(.roundedBorder)
                                        .help("SSH server hostname or IP address")
                                    
                                    if !configManager.recentHosts.isEmpty {
                                        Menu("Recent") {
                                            ForEach(configManager.recentHosts, id: \.self) { host in
                                                Button(host) {
                                                    configManager.host = host
                                                }
                                            }
                                        }
                                        .controlSize(.small)
                                    }
                                }
                            }
                            
            HStack {
                Text("Port:")
                    .frame(width: 100, alignment: .trailing)
                TextField("22", text: Binding(
                    get: { String(configManager.port) },
                    set: { configManager.port = Int($0) ?? 22 }
                ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .help("SSH port (default: 22)")
                Spacer()
            }
                            
                            HStack {
                                Text("Username:")
                                    .frame(width: 100, alignment: .trailing)
                                TextField(NSUserName(), text: $configManager.username)
                                    .textFieldStyle(.roundedBorder)
                                    .help("SSH username")
                            }
                            
                            HStack {
                                Text("Timeout:")
                                    .frame(width: 100, alignment: .trailing)
                                Stepper(value: $configManager.connectionTimeout, in: 5...60, step: 5) {
                                    Text("\(configManager.connectionTimeout) seconds")
                                }
                                .help("Connection timeout in seconds")
                                Spacer()
                            }
                        }
                        .padding()
                    }
                    
                    // Authentication Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Authentication", systemImage: "key.fill")
                                .font(.headline)
                            
                            HStack {
                                Text("Method:")
                                    .frame(width: 100, alignment: .trailing)
                                Picker("", selection: $configManager.authMethod) {
                                    ForEach(SSHConfigManager.AuthMethod.allCases, id: \.self) { method in
                                        Text(method.displayName).tag(method)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 250)
                                Spacer()
                            }
                            
                            // Password fields
                            if configManager.authMethod == .password {
                                HStack {
                                    Text("Password:")
                                        .frame(width: 100, alignment: .trailing)
                                    HStack {
                                        if showPasswordField {
                                            TextField("Enter password", text: $configManager.password)
                                                .textFieldStyle(.roundedBorder)
                                        } else {
                                            SecureField("Enter password", text: $configManager.password)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                        Button(action: { showPasswordField.toggle() }) {
                                            Image(systemName: showPasswordField ? "eye.slash" : "eye")
                                        }
                                        .buttonStyle(.plain)
                                        .help(showPasswordField ? "Hide password" : "Show password")
                                    }
                                }
                            }
                            
                            // Private key fields
                            if configManager.authMethod == .privateKey {
                                HStack {
                                    Text("Key Path:")
                                        .frame(width: 100, alignment: .trailing)
                                    TextField("~/.ssh/id_rsa", text: $configManager.privateKeyPath)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Browse...") {
                                        selectPrivateKeyFile()
                                    }
                                }
                                
                                HStack {
                                    Text("Passphrase:")
                                        .frame(width: 100, alignment: .trailing)
                                    HStack {
                                        if showPassphraseField {
                                            TextField("Optional", text: $configManager.passphrase)
                                                .textFieldStyle(.roundedBorder)
                                        } else {
                                            SecureField("Optional", text: $configManager.passphrase)
                                                .textFieldStyle(.roundedBorder)
                                        }
                                        Button(action: { showPassphraseField.toggle() }) {
                                            Image(systemName: showPassphraseField ? "eye.slash" : "eye")
                                        }
                                        .buttonStyle(.plain)
                                        .help(showPassphraseField ? "Hide passphrase" : "Show passphrase")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    
                    // Options Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Options", systemImage: "gearshape.fill")
                                .font(.headline)
                            
                            Toggle("Auto-connect on startup", isOn: $configManager.autoConnect)
                                .help("Automatically connect when the app starts")
                        }
                        .padding()
                    }
                    
                    // Actions
                    HStack(spacing: 16) {
                        Button("Test Connection") {
                            Task {
                                await testConnection()
                            }
                        }
                        .disabled(isTestingConnection)
                        
                        Button("Reset to Defaults") {
                            configManager.resetToDefaults()
                        }
                        
                        Spacer()
                        
                        if !testConnectionResult.isEmpty {
                            Text(testConnectionResult)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(testConnectionResult.contains("Success") ? .green : .red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 550)
    }
    
    private func selectPrivateKeyFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Private Key"
        openPanel.message = "Choose your SSH private key file"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = true
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".ssh")
        
        if openPanel.runModal() == .OK,
           let url = openPanel.url {
            // Convert to path relative to home if possible
            let homePath = NSHomeDirectory()
            let filePath = url.path
            if filePath.hasPrefix(homePath) {
                configManager.privateKeyPath = "~" + String(filePath.dropFirst(homePath.count))
            } else {
                configManager.privateKeyPath = filePath
            }
        }
    }
    
    @MainActor
    private func testConnection() async {
        isTestingConnection = true
        testConnectionResult = "Testing..."
        
        let validation = configManager.isConfigValid()
        guard validation.valid else {
            testConnectionResult = "❌ \(validation.message ?? "Invalid configuration")"
            isTestingConnection = false
            return
        }
        
        // 创建临时的SSH管理器来测试连接
        let testManager = NIOSSHManager()
        let config = configManager.currentConfig()
        
        do {
            let connectionId = try await testManager.connect(config: config)
            
            // 尝试执行简单命令
            let request = CommandRequest(command: "echo 'Connection test successful'")
            let result = try await testManager.execute(connectionId: connectionId, request: request)
            
            if result.exitCode == 0 {
                testConnectionResult = "✅ Success"
                // 添加到最近使用
                configManager.addToRecentHosts(config.host)
            } else {
                testConnectionResult = "⚠️ Connected but command failed"
            }
            
            // 断开连接
            try await testManager.disconnect(connectionId: connectionId)
        } catch {
            testConnectionResult = "❌ \(error.localizedDescription)"
        }
        
        isTestingConnection = false
        
        // 清除结果信息
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5秒后清除
            testConnectionResult = ""
        }
    }
}

// Preview provider for SwiftUI canvas
@available(macOS 11.0, *)
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
