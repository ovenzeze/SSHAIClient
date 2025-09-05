import SwiftUI

// MARK: - Cross-Platform Color Adapter

/// Cross-platform color adapter to handle NSColor (macOS) vs UIColor (iOS) differences
struct PlatformColor {
    #if os(macOS)
    static let controlBackgroundColor = NSColor.controlBackgroundColor
    static let windowBackgroundColor = NSColor.windowBackgroundColor
    static let textBackgroundColor = NSColor.textBackgroundColor
    #elseif os(iOS)
    static let controlBackgroundColor = UIColor.systemGray6
    static let windowBackgroundColor = UIColor.systemBackground
    static let textBackgroundColor = UIColor.secondarySystemBackground
    #else
    // Fallback for other platforms
    static let controlBackgroundColor = UIColor.lightGray
    static let windowBackgroundColor = UIColor.white
    static let textBackgroundColor = UIColor.white
    #endif
}

// MARK: - Suggestion Card

@available(macOS 11.0, *)
public struct SuggestionCard: View {
    let suggestion: CommandSuggestion
    let onAccept: () -> Void
    let onExecute: () -> Void
    
    public init(suggestion: CommandSuggestion, onAccept: @escaping () -> Void, onExecute: @escaping () -> Void) {
        self.suggestion = suggestion
        self.onAccept = onAccept
        self.onExecute = onExecute
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // AI建议标题
            HStack {
                Text("AI Suggestion")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 风险级别指示器
                RiskBadge(risk: suggestion.risk)
            }
            
            // 命令内容
            Text(suggestion.command)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .padding(8)
                .background(Color(PlatformColor.textBackgroundColor))
                .cornerRadius(4)
            
            // 说明文字
            Text(suggestion.explanation)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 操作按钮
            HStack {
                Button("Copy", action: onAccept)
                    .controlSize(.small)
                
                Button("Execute", action: onExecute)
                    .modifier(BorderedProminentButtonModifier())
                    .controlSize(.small)
                
                Spacer()
                
                Text("Confidence: \(Int(suggestion.confidence * 100))%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(PlatformColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(suggestion.risk == .dangerous ? Color.red : Color.clear, lineWidth: 1)
        )
    }
}

@available(macOS 11.0, *)
public struct RiskBadge: View {
    let risk: RiskLevel
    
    public var body: some View {
        Text(risk.rawValue.capitalized)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(3)
    }
    
    private var backgroundColor: Color {
        switch risk {
        case .safe: return .green.opacity(0.2)
        case .caution: return .orange.opacity(0.2)
        case .dangerous: return .red.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch risk {
        case .safe: return .green
        case .caution: return .orange
        case .dangerous: return .red
        }
    }
}

// MARK: - Compatibility Modifiers

@available(macOS 11.0, *)
public struct TextSelectionModifier: ViewModifier {
    public func body(content: Content) -> some View {
        if #available(macOS 12.0, *) {
            content.textSelection(.enabled)
        } else {
            content
        }
    }
}

@available(macOS 11.0, *)
public struct OnSubmitModifier: ViewModifier {
    let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public func body(content: Content) -> some View {
        if #available(macOS 12.0, *) {
            content.onSubmit(action)
        } else {
            content
        }
    }
}

@available(macOS 11.0, *)
public struct BorderedProminentButtonModifier: ViewModifier {
    public func body(content: Content) -> some View {
        if #available(macOS 12.0, *) {
            content.buttonStyle(.borderedProminent)
        } else {
            content.buttonStyle(DefaultButtonStyle())
        }
    }
}

// MARK: - Focus Management

@available(macOS 11.0, *)
public struct FocusOnAppearModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .onAppear {
                #if os(macOS)
                // Delay to ensure window is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let window = NSApp.keyWindow ?? NSApp.windows.first {
                        // Make window key and order front
                        window.makeKeyAndOrderFront(nil)
                        
                        // Find the text field and make it first responder
                        if let contentView = window.contentView {
                            makeTextFieldFirstResponder(in: contentView)
                        }
                    }
                }
                #endif
            }
    }
    
    #if os(macOS)
    private func makeTextFieldFirstResponder(in view: NSView) {
        // Recursively search for NSTextField and make it first responder
        if let textField = view as? NSTextField {
            textField.window?.makeFirstResponder(textField)
            return
        }
        
        for subview in view.subviews {
            makeTextFieldFirstResponder(in: subview)
        }
    }
    #endif
}

// MARK: - Window Focus Helper Extension

@available(macOS 11.0, *)
public extension View {
    func ensureWindowFocus() -> some View {
        self.modifier(WindowFocusModifier())
    }
}

@available(macOS 11.0, *)
private struct WindowFocusModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                #if os(macOS)
                // Activate the app and make window key
                NSApp.activate(ignoringOtherApps: true)
                
                DispatchQueue.main.async {
                    if let window = NSApp.keyWindow ?? NSApp.windows.first {
                        window.makeKeyAndOrderFront(nil)
                        window.makeKey()
                        
                        // Clear any existing first responder and reset
                        window.makeFirstResponder(nil)
                        
                        // After a brief delay, find and focus the text field
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusFirstTextField(in: window.contentView)
                        }
                    }
                }
                #endif
            }
            #if os(macOS)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                // Re-focus when app becomes active
                if let window = NSApp.keyWindow {
                    focusFirstTextField(in: window.contentView)
                }
            }
            #endif
    }
    
    #if os(macOS)
    private func focusFirstTextField(in view: NSView?) {
        guard let view = view else { return }
        
        if let textField = findTextField(in: view) {
            textField.window?.makeFirstResponder(textField)
        }
    }
    
    private func findTextField(in view: NSView) -> NSTextField? {
        if let textField = view as? NSTextField {
            return textField
        }
        
        for subview in view.subviews {
            if let found = findTextField(in: subview) {
                return found
            }
        }
        
        return nil
    }
    #endif
}
