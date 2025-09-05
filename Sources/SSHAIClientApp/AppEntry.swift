import SwiftUI
import SSHAIClient
#if os(macOS)
import AppKit
#endif

@available(macOS 11.0, *)
@main
struct SSHAIClientApp: App {
    init() {
        #if os(macOS)
        // Force the app to become a proper GUI app that can receive events
        let _ = NSApplication.shared
        NSApp.setActivationPolicy(.regular)
        
        // This is crucial: tell macOS this is a foreground app
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
        }
        #endif
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 393, height: 852) // iPhone 15 Pro size
                .frame(minWidth: 393, minHeight: 852)
        }
        .applyWindowResizability()
        .windowToolbarStyle(.unified)
        .commands {
            // This helps with window activation
            CommandGroup(replacing: .newItem) { }
        }
    }
}

// MARK: - Compatibility Extensions

@available(macOS 11.0, *)
extension Scene {
    func applyWindowResizability() -> some Scene {
        #if os(macOS)
        if #available(macOS 13.0, *) {
            return self.windowResizability(.contentSize)
        } else {
            return self
        }
        #else
        // On iOS/tvOS/watchOS, do nothing.
        return self
        #endif
    }
}

