import SwiftUI

// MARK: - Tab Model and Helpers

@available(macOS 11.0, *)
private struct TerminalTab: Identifiable, Hashable {
    let id: UUID
    var title: String
    var history: [String]
    init(title: String, history: [String] = []) {
        self.id = UUID()
        self.title = title
        self.history = history
    }
}

@available(macOS 11.0, *)
private func highlightedCommandText(_ command: String) -> some View {
    // Minimal, safe syntax highlighting by keywords
    let dangerKeywords = ["rm", "sudo", "dd", "mkfs", "shutdown", "reboot"]
    let vcsKeywords = ["git", "branch", "commit", "push", "pull", "rebase"]
    let sshKeywords = ["ssh", "scp", "sftp"]

    let parts = command.split(separator: " ")
    return HStack(spacing: 4) {
        ForEach(Array(parts.enumerated()), id: \.offset) { _, token in
            let t = String(token)
            let color: Color = dangerKeywords.contains(t) ? .red : (vcsKeywords.contains(t) ? .blue : (sshKeywords.contains(t) ? .green : .primary))
            Text(t)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(color)
        }
    }
}

@available(macOS 11.0, *)
private struct TerminalTabsBar: View {
    @Binding var tabs: [TerminalTab]
    @Binding var selected: UUID
    var onNew: () -> Void
    var onClose: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs) { tab in
                    HStack(spacing: 6) {
                        Text(tab.title)
                            .font(.system(size: 12, weight: selected == tab.id ? .semibold : .regular))
                            .lineLimit(1)
                            .padding(.vertical, 6)
                            .padding(.leading, 10)
                        Button(action: { onClose(tab.id) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                        .help("Close Tab (⌘W)")
                    }
                    .background(selected == tab.id ? Color.accentColor.opacity(0.22) : Color.clear)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(selected == tab.id ? Color.accentColor.opacity(0.9) : Color.secondary.opacity(0.12), lineWidth: selected == tab.id ? 1 : 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture { withAnimation(.easeInOut) { selected = tab.id } }
                    .contextMenu {
                        Button("Close") { onClose(tab.id) }
                        Button("New Tab") { onNew() }
                    }
                }
                Button(action: onNew) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("New Tab (⌘T)")
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 30)
        .background(Color(PlatformColor.controlBackgroundColor))
    }
}

// MARK: - Legacy View (macOS 11)

@available(macOS 11.0, *)
private struct TerminalView_Legacy: View {
    @ObservedObject var viewModel: TerminalViewModel
    @State private var inputText = ""
    @State private var tabs: [TerminalTab] = [TerminalTab(title: "Tab 1")]
    @State private var selectedTabId: UUID = UUID()
    @State private var isProcessing = false
    
    private var suggestions: [String] {
        let base = ["ssh", "scp", "sftp", "ls -la", "cd ", "cat ", "tail -f ", "git status", "git pull", "top -l 1"]
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return base.filter { $0.hasPrefix(trimmed) && $0 != trimmed }.prefix(5).map { $0 }
    }

    init(viewModel: TerminalViewModel) {
        self.viewModel = viewModel
    }

var body: some View {
        VStack(spacing: 0) {
            // Tabs bar
            TerminalTabsBar(tabs: $tabs, selected: $selectedTabId, onNew: addTab, onClose: closeTab)
            
            // Command history/output area
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.commandHistory) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("[\(item.formattedTimestamp)]").foregroundColor(.gray).font(.system(size: 11, design: .monospaced))
                                    Text("$").foregroundColor(.green).font(.system(.body, design: .monospaced))
                                    Text(item.command).font(.system(size: 14, design: .monospaced)).foregroundColor(.blue).modifier(TextSelectionModifier())
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                                if !item.output.isEmpty {
                                    Text(item.output)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                        .modifier(TextSelectionModifier())
                                        .padding(.horizontal, 12)
                                        .padding(.leading, 20)
                                }
                                if let error = item.error, !error.isEmpty {
                                    Text(error)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.red)
                                        .modifier(TextSelectionModifier())
                                        .padding(.horizontal, 12)
                                        .padding(.leading, 20)
                                }
                            }
                            .id(item.id)
                        }
                        if let suggestion = viewModel.currentSuggestion {
                            SuggestionCard(suggestion: suggestion) {
                                inputText = suggestion.command
                            } onExecute: {
                                Task { await viewModel.executeSuggestion() }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: viewModel.commandHistory.count) { _ in
                        if let lastItem = viewModel.commandHistory.last {
                            withAnimation { proxy.scrollTo(lastItem.id, anchor: .bottom) }
                        }
                    }
                }
            }
                        if let suggestion = viewModel.currentSuggestion {
                            SuggestionCard(suggestion: suggestion) {
                                inputText = suggestion.command
                            } onExecute: {
                                Task { await viewModel.executeSuggestion() }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: viewModel.commandHistory.count) { _ in
                        if let lastItem = viewModel.commandHistory.last {
                            withAnimation { proxy.scrollTo(lastItem.id, anchor: .bottom) }
                        }
                    }
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
            .zIndex(0)
            
            Divider()
            
            // Input area
            VStack(spacing: 6) {
                HStack {
TextField("Enter command or natural language...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .disableAutocorrection(true)
                        .layoutPriority(1)
                        .modifier(OnSubmitModifier { handleInput() })
                        .modifier(FocusOnAppearModifier())
                    
                    if let first = suggestions.first {
                        Button(action: { inputText = first }) {
                            Image(systemName: "arrow.turn.down.right")
                        }
                        .help("Accept suggestion")
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: handleInput) {
                        if isProcessing { ProgressView().scaleEffect(0.8) } else { Image(systemName: "return") }
                    }
                    .disabled(inputText.isEmpty || isProcessing)
                }
                
                // Autocomplete overlay (simple list)
                if !suggestions.isEmpty {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(suggestions, id: \.self) { s in
                                Text(s)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(PlatformColor.textBackgroundColor))
                                    .cornerRadius(4)
                                    .onTapGesture { inputText = s }
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(Color(PlatformColor.controlBackgroundColor))
            .zIndex(1)
        }
        .ensureWindowFocus()
        .onAppear { if tabs.isEmpty { addTab() }; if selectedTabId == UUID() { selectedTabId = tabs.first!.id } }
    }
    
    private var currentHistory: [String] {
        if let idx = tabs.firstIndex(where: { $0.id == selectedTabId }) { return tabs[idx].history }
        return []
    }
    
    private func mutateCurrentHistory(_ transform: (inout [String]) -> Void) {
        if let idx = tabs.firstIndex(where: { $0.id == selectedTabId }) {
            transform(&tabs[idx].history)
        }
    }
    
    private func addTab() {
        let count = tabs.count + 1
        let new = TerminalTab(title: "Tab \(count)")
        tabs.append(new)
        selectedTabId = new.id
    }
    
    private func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if tabs.isEmpty { addTab() }
        selectedTabId = tabs.first!.id
    }
    
    private func handleInput() {
        guard !inputText.isEmpty, !isProcessing else { return }
        let input = inputText
        inputText = ""
        isProcessing = true
        mutateCurrentHistory { $0.append(input) }
        Task {
            await viewModel.handleAutoInput(input)
            await MainActor.run { isProcessing = false }
        }
    }
}

// MARK: - Modern View (macOS 12+)

@available(macOS 12.0, *)
private struct TerminalView_Modern: View {
    @ObservedObject var viewModel: TerminalViewModel
    @State private var inputText = ""
    @State private var tabs: [TerminalTab] = [TerminalTab(title: "Tab 1")]
    @State private var selectedTabId: UUID = UUID()
    @State private var isProcessing = false
    @FocusState private var isTextFieldFocused: Bool

    private var suggestions: [String] {
        let base = ["ssh", "scp", "sftp", "ls -la", "cd ", "cat ", "tail -f ", "git status", "git pull", "top -l 1"]
        let trimmed = inputText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return base.filter { $0.hasPrefix(trimmed) && $0 != trimmed }.prefix(5).map { $0 }
    }

    init(viewModel: TerminalViewModel) {
        self.viewModel = viewModel
    }

var body: some View {
        VStack(spacing: 0) {
            // Tabs bar
            TerminalTabsBar(tabs: $tabs, selected: $selectedTabId, onNew: addTab, onClose: closeTab)
            
            // Command history/output area
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.commandHistory) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("[\(item.formattedTimestamp)]").foregroundColor(.gray).font(.system(size: 11, design: .monospaced))
                                    Text("$").foregroundColor(.green).font(.system(.body, design: .monospaced))
                                    Text(item.command).font(.system(size: 14, design: .monospaced)).foregroundColor(.blue).modifier(TextSelectionModifier())
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                                if !item.output.isEmpty {
                                    Text(item.output)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                        .modifier(TextSelectionModifier())
                                        .padding(.horizontal, 12)
                                        .padding(.leading, 20)
                                }
                                if let error = item.error, !error.isEmpty {
                                    Text(error)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.red)
                                        .modifier(TextSelectionModifier())
                                        .padding(.horizontal, 12)
                                        .padding(.leading, 20)
                                }
                            }
                            .id(item.id)
                        }
                    
                        if let suggestion = viewModel.currentSuggestion {
                            SuggestionCard(suggestion: suggestion) {
                                inputText = suggestion.command
                            } onExecute: {
                                Task { await viewModel.executeSuggestion() }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: viewModel.commandHistory.count) { _ in
                        if let lastItem = viewModel.commandHistory.last {
                            withAnimation { proxy.scrollTo(lastItem.id, anchor: .bottom) }
                        }
                    }
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
            .zIndex(0)
            
            Divider()
            
            // Input area with autocomplete
            VStack(spacing: 6) {
                HStack {
TextField("Enter command or natural language...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .disableAutocorrection(true)
                        .layoutPriority(1)
                        .focused($isTextFieldFocused)
                        .modifier(OnSubmitModifier { handleInput() })
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                            isTextFieldFocused = true
                        }
                    if let first = suggestions.first {
                        Button(action: { inputText = first }) {
                            Image(systemName: "arrow.turn.down.right")
                        }
                        .help("Accept suggestion")
                        .buttonStyle(.plain)
                    }
                    Button(action: handleInput) {
                        if isProcessing { ProgressView().scaleEffect(0.8) } else { Image(systemName: "return") }
                    }
                    .disabled(inputText.isEmpty || isProcessing)
                }
                if !suggestions.isEmpty {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(suggestions, id: \.self) { s in
                                Text(s)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(PlatformColor.textBackgroundColor))
                                    .cornerRadius(4)
                                    .onTapGesture { inputText = s }
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(Color(PlatformColor.controlBackgroundColor))
            .zIndex(1)
        }
        .ensureWindowFocus()
        .onAppear {
            isTextFieldFocused = true
            if tabs.isEmpty { addTab() }
            if selectedTabId == UUID() { selectedTabId = tabs.first!.id }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { isTextFieldFocused = true }
        }
    }
    
    private var currentHistory: [String] {
        if let idx = tabs.firstIndex(where: { $0.id == selectedTabId }) { return tabs[idx].history }
        return []
    }
    private func mutateCurrentHistory(_ transform: (inout [String]) -> Void) {
        if let idx = tabs.firstIndex(where: { $0.id == selectedTabId }) { transform(&tabs[idx].history) }
    }
    private func addTab() {
        let count = tabs.count + 1
        let new = TerminalTab(title: "Tab \(count)")
        tabs.append(new)
        selectedTabId = new.id
    }
    private func closeTab(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        tabs.remove(at: idx)
        if tabs.isEmpty { addTab() }
        selectedTabId = tabs.first!.id
    }
    
    private func handleInput() {
        guard !inputText.isEmpty, !isProcessing else { return }
        let input = inputText
        inputText = ""
        isProcessing = true
        mutateCurrentHistory { $0.append(input) }
        Task {
            await viewModel.handleAutoInput(input)
            await MainActor.run { isProcessing = false }
        }
    }
}


// MARK: - Public Dispatcher View

@available(macOS 11.0, *)
public struct TerminalView: View {
    @ObservedObject var viewModel: TerminalViewModel

    public var body: some View {
        if #available(macOS 12.0, *) {
            TerminalView_Modern(viewModel: viewModel)
        } else {
            TerminalView_Legacy(viewModel: viewModel)
        }
    }
}

