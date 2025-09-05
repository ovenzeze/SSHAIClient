import SwiftUI
import Combine
#if os(macOS)
import AppKit
#endif

@available(macOS 11.0, *)
public struct SettingsView: View {
    // Main settings (from main)
    @AppStorage("appearanceMode") private var appearanceMode: String = "system" // system | light | dark
    @AppStorage("codeTheme") private var codeTheme: String = "Monokai Pro"
    @AppStorage("aiInlineSuggestions") private var aiInlineSuggestions: Bool = true
    @AppStorage("aiModel") private var aiModel: String = "gpt-4o-mini"
    @AppStorage("shortcutNewTab") private var shortcutNewTab: String = "⌘T"
    @AppStorage("shortcutCloseTab") private var shortcutCloseTab: String = "⌘W"

    // SSH settings (from our branch)
    @StateObject private var configManager = SSHConfigManager.shared
    @State private var showPasswordField = false
    @State private var showPassphraseField = false
    @State private var testConnectionResult: String = ""
    @State private var isTestingConnection = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            TabView {
                generalTab
                    .tabItem { Label("General", systemImage: "gear") }
                aiTab
                    .tabItem { Label("AI", systemImage: "brain.head.profile") }
                shortcutsTab
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                sshTab
                    .tabItem { Label("SSH", systemImage: "lock.shield") }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .background(Color(PlatformColor.windowBackgroundColor))
        .accessibilityLabel(Text("Settings"))
    }

    private var generalTab: some View {
        Form {
            Picker("Appearance", selection: $appearanceMode) {
                Text("System").tag("system")
                Text("Light").tag("light")
                Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            .help("Choose interface appearance")

            Picker("Code Theme", selection: $codeTheme) {
                Text("Monokai Pro").tag("Monokai Pro")
                Text("GitHub Light").tag("GitHub Light")
                Text("Dracula").tag("Dracula")
            }
            .help("Syntax highlighting theme")
        }
        .padding()
    }

    private var aiTab: some View {
        Form {
            Toggle("Enable inline suggestions", isOn: $aiInlineSuggestions)
            Picker("AI Model", selection: $aiModel) {
                Text("gpt-4o-mini").tag("gpt-4o-mini")
                Text("gpt-4o").tag("gpt-4o")
                Text("local-llm").tag("local-llm")
            }
            .help("Choose the AI model used for suggestions")
        }
        .padding()
    }

    private var shortcutsTab: some View {
        Form {
            HStack {
                Text("New Tab")
                Spacer()
                ShortcutField(text: $shortcutNewTab)
            }
            HStack {
                Text("Close Tab")
                Spacer()
                ShortcutField(text: $shortcutCloseTab)
            }
            Text("Tip: Click the field and press the desired key combination.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    private var sshTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Connection", systemImage: "network").font(.headline)
                        HStack(alignment: .top) {
                            Text("Host:").frame(width: 100, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("localhost", text: $configManager.host)
                                    .textFieldStyle(.roundedBorder)
                                if !configManager.recentHosts.isEmpty {
                                    Menu("Recent") {
                                        ForEach(configManager.recentHosts, id: \.self) { host in
                                            Button(host) { configManager.host = host }
                                        }
                                    }.controlSize(.small)
                                }
                            }
                        }
                        HStack {
                            Text("Port:").frame(width: 100, alignment: .trailing)
                            TextField("22", text: Binding(get: { String(configManager.port) }, set: { configManager.port = Int($0) ?? 22 }))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                            Spacer()
                        }
                        HStack {
                            Text("Username:").frame(width: 100, alignment: .trailing)
                            TextField(NSUserName(), text: $configManager.username)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Text("Timeout:").frame(width: 100, alignment: .trailing)
                            Stepper(value: $configManager.connectionTimeout, in: 5...60, step: 5) {
                                Text("\(configManager.connectionTimeout) seconds")
                            }
                            Spacer()
                        }
                    }.padding()
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Authentication", systemImage: "key.fill").font(.headline)
                        HStack {
                            Text("Method:").frame(width: 100, alignment: .trailing)
                            Picker("", selection: $configManager.authMethod) {
                                ForEach(SSHConfigManager.AuthMethod.allCases, id: \.self) { Text($0.displayName).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 250)
                            Spacer()
                        }
                        if configManager.authMethod == .password {
                            HStack {
                                Text("Password:").frame(width: 100, alignment: .trailing)
                                HStack {
                                    if showPasswordField {
                                        TextField("Enter password", text: $configManager.password).textFieldStyle(.roundedBorder)
                                    } else {
                                        SecureField("Enter password", text: $configManager.password).textFieldStyle(.roundedBorder)
                                    }
                                    Button(action: { showPasswordField.toggle() }) { Image(systemName: showPasswordField ? "eye.slash" : "eye") }.buttonStyle(.plain)
                                }
                            }
                        }
                        if configManager.authMethod == .privateKey {
                            HStack {
                                Text("Key Path:").frame(width: 100, alignment: .trailing)
                                TextField("~/.ssh/id_rsa", text: $configManager.privateKeyPath).textFieldStyle(.roundedBorder)
                                Button("Browse...") { selectPrivateKeyFile() }
                            }
                            HStack {
                                Text("Passphrase:").frame(width: 100, alignment: .trailing)
                                HStack {
                                    if showPassphraseField {
                                        TextField("Optional", text: $configManager.passphrase).textFieldStyle(.roundedBorder)
                                    } else {
                                        SecureField("Optional", text: $configManager.passphrase).textFieldStyle(.roundedBorder)
                                    }
                                    Button(action: { showPassphraseField.toggle() }) { Image(systemName: showPassphraseField ? "eye.slash" : "eye") }.buttonStyle(.plain)
                                }
                            }
                        }
                    }.padding()
                }
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Options", systemImage: "gearshape.fill").font(.headline)
                        Toggle("Auto-connect on startup", isOn: $configManager.autoConnect)
                    }.padding()
                }
                HStack(spacing: 16) {
                    Button("Test Connection") { Task { await testConnection() } }.disabled(isTestingConnection)
                    Button("Reset to Defaults") { configManager.resetToDefaults() }
                    Spacer()
                    if !testConnectionResult.isEmpty {
                        Text(testConnectionResult)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(testConnectionResult.contains("Success") ? .green : .red)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1)).cornerRadius(4)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Missing Methods
    private func selectPrivateKeyFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Private Key File"
        panel.message = "Choose your SSH private key file"
        panel.prompt = "Select"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.canCreateDirectories = false
        panel.directoryURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".ssh")
        
        if panel.runModal() == .OK {
            if let url = panel.url {
                configManager.privateKeyPath = url.path
            }
        }
    }
    
    private func testConnection() async {
        await MainActor.run { 
            isTestingConnection = true 
            testConnectionResult = "Testing..."
        }
        
        do {
            // Validate required fields
            guard !configManager.host.isEmpty else {
                await MainActor.run {
                    testConnectionResult = "❌ Failed: Host is required"
                    isTestingConnection = false
                }
                return
            }
            guard !configManager.username.isEmpty else {
                await MainActor.run {
                    testConnectionResult = "❌ Failed: Username is required"
                    isTestingConnection = false
                }
                return
            }
            
            // Test connection using NIOSSHManager
            let sshManager = NIOSSHManager()
            
            // Create SSH config based on auth method
            let authConfig: SSHConfig.Authentication
            if configManager.authMethod == .password {
                guard !configManager.password.isEmpty else {
                    await MainActor.run {
                        testConnectionResult = "❌ Failed: Password is required"
                        isTestingConnection = false
                    }
                    return
                }
                authConfig = .password(configManager.password)
            } else {
                // Private key auth - currently not supported by NIOSSHManager
                await MainActor.run {
                    testConnectionResult = "❌ Failed: Private key authentication not yet implemented"
                    isTestingConnection = false
                }
                return
            }
            
            let config = SSHConfig(
                host: configManager.host,
                port: configManager.port,
                username: configManager.username,
                authentication: authConfig,
                timeoutSeconds: TimeInterval(configManager.connectionTimeout)
            )
            
            // Try to connect
            let connectionId = try await sshManager.connect(config: config)
            
            // Disconnect after successful test
            try await sshManager.disconnect(connectionId: connectionId)
            
            // Test successful if we got here
            await MainActor.run {
                testConnectionResult = "✅ Success: Connection established"
                isTestingConnection = false
            }
        } catch {
            await MainActor.run {
                testConnectionResult = "❌ Failed: \(error.localizedDescription)"
                isTestingConnection = false
            }
        }
    }
}

// MARK: - Shortcut Field (Minimal Recorder)

@available(macOS 11.0, *)
private struct ShortcutField: View {
    @Binding var text: String
    @State private var isRecording = false

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
            .onTapGesture { isRecording = true }
            .background(RecorderRepresentable(text: $text, isRecording: $isRecording).frame(width: 0, height: 0))
            .accessibilityLabel(Text("Shortcut Field"))
    }
}

#if os(macOS)
@available(macOS 11.0, *)
private struct RecorderRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            guard isRecording else { return event }
            let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            var parts: [String] = []
            if mods.contains(.command) { parts.append("⌘") }
            if mods.contains(.option) { parts.append("⌥") }
            if mods.contains(.shift) { parts.append("⇧") }
            if mods.contains(.control) { parts.append("⌃") }
            if let chars = event.charactersIgnoringModifiers?.uppercased(), !chars.isEmpty {
                parts.append(chars)
            }
            text = parts.joined()
            DispatchQueue.main.async { isRecording = false }
            return nil // consume
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
