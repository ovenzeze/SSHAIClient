import SwiftUI

// MARK: - Legacy View (macOS 11)

@available(macOS 11.0, *)
private struct TerminalView_Legacy: View {
    @ObservedObject var viewModel: TerminalViewModel
    @State private var inputText = ""
    @State private var isProcessing = false

    init(viewModel: TerminalViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Command history/output area
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.commandHistory) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                // Command line
                                HStack {
                                    Text("[\(item.formattedTimestamp)]")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 11, design: .monospaced))
                                    
                                    Text("$")
                                        .foregroundColor(.green)
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Text(item.command)
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .modifier(TextSelectionModifier())
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                                
                                // Output
                                if !item.output.isEmpty {
                                    Text(item.output)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                        .modifier(TextSelectionModifier())
                                        .padding(.horizontal, 12)
                                        .padding(.leading, 20)
                                }
                                
                                // Error output
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
                    
                        // Show current suggestion if available
                        if let suggestion = viewModel.currentSuggestion {
                            SuggestionCard(suggestion: suggestion) {
                                // Accept suggestion
                                inputText = suggestion.command
                            } onExecute: {
                                // Execute suggestion directly
                                Task {
                                    await viewModel.executeSuggestion()
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: viewModel.commandHistory.count) { _ in
                        // Auto-scroll to bottom when new command is added
                        if let lastItem = viewModel.commandHistory.last {
                            withAnimation {
                                proxy.scrollTo(lastItem.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
            .zIndex(0)
            
            Divider()
            
            // Input area
            HStack {
                TextField("Enter command or natural language...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .modifier(OnSubmitModifier { handleInput() })
                    .modifier(FocusOnAppearModifier())
                
                Button(action: handleInput) {
                    if isProcessing {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "return")
                    }
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding(12)
            .background(Color(PlatformColor.controlBackgroundColor))
            .zIndex(1)
        }
        .ensureWindowFocus()
    }
    
    private func handleInput() {
        guard !inputText.isEmpty, !isProcessing else { return }
        
        let input = inputText
        inputText = ""
        isProcessing = true
        
        Task {
            // Process input through view model
            await viewModel.handleAutoInput(input)
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

// MARK: - Modern View (macOS 12+)

@available(macOS 12.0, *)
private struct TerminalView_Modern: View {
    @ObservedObject var viewModel: TerminalViewModel
    @State private var inputText = ""
    @State private var isProcessing = false
    @FocusState private var isTextFieldFocused: Bool

    init(viewModel: TerminalViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            // Command history/output area
            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.commandHistory) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                // Command line
                                HStack {
                                    Text("[\(item.formattedTimestamp)]")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 11, design: .monospaced))
                                    
                                    Text("$")
                                        .foregroundColor(.green)
                                        .font(.system(.body, design: .monospaced))
                                    
                                    Text(item.command)
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(.blue)
                                        .modifier(TextSelectionModifier())
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                                
                                // Output
                                if !item.output.isEmpty {
                                    Text(item.output)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                        .modifier(TextSelectionModifier())
                                        .padding(.horizontal, 12)
                                        .padding(.leading, 20)
                                }
                                
                                // Error output
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
                    
                        // Show current suggestion if available
                        if let suggestion = viewModel.currentSuggestion {
                            SuggestionCard(suggestion: suggestion) {
                                // Accept suggestion
                                inputText = suggestion.command
                            } onExecute: {
                                // Execute suggestion directly
                                Task {
                                    await viewModel.executeSuggestion()
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: viewModel.commandHistory.count) { _ in
                        // Auto-scroll to bottom when new command is added
                        if let lastItem = viewModel.commandHistory.last {
                            withAnimation {
                                proxy.scrollTo(lastItem.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .background(Color.black)
            .foregroundColor(.white)
            .zIndex(0)
            
            Divider()
            
            // Input area
            HStack {
                TextField("Enter command or natural language...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .focused($isTextFieldFocused)
                    .modifier(OnSubmitModifier { handleInput() })
                    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                        isTextFieldFocused = true
                    }
                
                Button(action: handleInput) {
                    if isProcessing {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Image(systemName: "return")
                    }
                }
                .disabled(inputText.isEmpty || isProcessing)
            }
            .padding(12)
            .background(Color(PlatformColor.controlBackgroundColor))
            .zIndex(1)
        }
        .ensureWindowFocus()
        .onAppear {
            isTextFieldFocused = true
            // Ensure text field gets focus after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func handleInput() {
        guard !inputText.isEmpty, !isProcessing else { return }
        
        let input = inputText
        inputText = ""
        isProcessing = true
        
        Task {
            // Process input through view model
            await viewModel.handleAutoInput(input)
            
            await MainActor.run {
                isProcessing = false
            }
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

