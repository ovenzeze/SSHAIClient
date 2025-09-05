import SwiftUI
import Combine

@available(macOS 11.0, *)
public struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = "system" // system | light | dark
    @AppStorage("codeTheme") private var codeTheme: String = "Monokai Pro"
    @AppStorage("aiInlineSuggestions") private var aiInlineSuggestions: Bool = true
    @AppStorage("aiModel") private var aiModel: String = "gpt-4o-mini"
    @AppStorage("shortcutNewTab") private var shortcutNewTab: String = "⌘T"
    @AppStorage("shortcutCloseTab") private var shortcutCloseTab: String = "⌘W"

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
import AppKit
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
