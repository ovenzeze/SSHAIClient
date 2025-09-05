# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

SSH AI Client is an AI-enhanced macOS SSH client built with SwiftUI. It combines traditional SSH terminal functionality with AI-powered command generation and intent classification to improve developer productivity.

### Core Architecture

The project follows a modular MVVM architecture with clear separation of concerns:

- **App Layer**: SwiftUI application entry point
- **UI Layer**: SwiftUI views and components  
- **Features Layer**: ViewModels containing business logic
- **Core Layer**: Foundational services (AI, Network, Data)

Key architectural principles:
- Protocol-based dependency injection for testability
- Local-first AI processing with cloud fallback
- Async/await throughout with @MainActor for UI updates
- Sendable compliance for concurrent safety

## Development Commands

### Build and Run
```bash
# Run the executable directly
swift run SSHAIClientApp

# Build only 
swift build

# Run built executable
./.build/debug/SSHAIClientApp

# Open in Xcode
open Package.swift
```

### Testing
```bash
# Run all tests
swift test

# Run specific test target
swift test --filter SSHAIClientTests

# Run with verbose output
swift test --verbose
```

### Package Management
```bash
# Update dependencies
swift package update

# Reset package cache (if dependencies issues)
swift package reset

# Generate Xcode project (if needed)
swift package generate-xcodeproj
```

## Core Components

### 1. Intent Classification System
- **`HybridIntentClassifier`**: Routes user input as either direct commands or AI queries
- **Flow**: Local cache → Rule-based → Apple Intelligence → Remote API fallback
- **Location**: `Sources/SSHAIClient/Core/AI/`

### 2. Command Generation
- **`CommandGenerator`**: Converts natural language to shell commands using rule-based patterns
- **`CommandGenerating` Protocol**: Abstraction for different generation strategies
- **Location**: `Sources/SSHAIClient/Core/AI/CommandGenerator.swift`

### 3. SSH Connection Management
- **`SSHManaging` Protocol**: Abstracts SSH operations for dependency injection
- **`MockSSHManager`**: Test implementation that simulates SSH responses
- **`NIOSSHManager`**: Production implementation using SwiftNIO SSH (minimal implementation)
- **Location**: `Sources/SSHAIClient/Core/Network/`

### 4. Terminal Interface
- **`TerminalViewModel`**: Orchestrates terminal state, SSH connections, and AI interactions
- **`ContentView`**: Main SwiftUI interface with terminal emulation
- **Auto Mode**: Seamlessly handles both direct commands and natural language queries

## Key Design Patterns

### Protocol-Based Architecture
All major components use protocols for dependency injection:
- `SSHManaging` for SSH operations
- `CommandGenerating` for AI command generation  
- Enables easy testing with mock implementations

### Hybrid AI Strategy
1. **Local Classification**: Rule-based patterns for common commands
2. **Device AI**: Apple Intelligence for privacy-preserving classification
3. **Cloud Fallback**: Remote API when local methods are insufficient
4. **Caching**: Results cached locally for performance

### Concurrent Safety
- All data types implement `Sendable`
- ViewModels use `@MainActor` for UI updates
- Actor isolation prevents data races in SSH connection management

## Testing Strategy

### Unit Tests Structure
- **`CommandGeneratorTests`**: Test rule-based command generation
- **`TerminalViewModelTests`**: Test business logic and state management
- Mock implementations enable isolated testing

### Running Tests
Focus on testing business logic in ViewModels rather than UI components. The protocol-based architecture makes dependency injection straightforward for testing.

## Development Workflow

### For New Features
1. Define protocols in Core layer if needed
2. Implement business logic in Features ViewModels
3. Create SwiftUI views that observe ViewModels
4. Add corresponding tests with mock dependencies

### For SSH Features
- Always implement against `SSHManaging` protocol
- Test with `MockSSHManager` first
- Real SSH implementation uses SwiftNIO SSH

### For AI Features
- Follow the hybrid strategy pattern
- Start with rule-based logic in `CommandGenerator`
- Consider Apple Intelligence integration for device-side processing
- Add fallback to remote APIs when needed

## Common Development Patterns

### Adding New Command Rules
Extend `CommandGenerator.generateBasicCommand()` with new pattern matching:
```swift
if lowercaseQuery.contains("your pattern") {
    return CommandSuggestion(
        command: "your command",
        explanation: "What this does",
        risk: .safe/.caution/.dangerous,
        confidence: 0.0-1.0
    )
}
```

### SSH Connection Flow
1. Create `SSHConfig` with connection parameters
2. Call `connect()` on SSH manager to get connection UUID  
3. Use UUID for `execute()` calls with `CommandRequest`
4. Handle `CommandResult` and update UI accordingly

### AI Integration Points
- **Intent Classification**: `HybridIntentClassifier.classify()`
- **Command Generation**: `CommandGenerator.generate()`
- **Error Analysis**: `ErrorAnalyzer` (interface defined, implementation minimal)

## Dependencies

- **SwiftNIO SSH**: Official Apple SSH implementation
- **SwiftTerm**: Terminal emulator component  
- **SQLite.swift**: Local data persistence
- **Core ML**: For on-device AI capabilities

## Compatibility Notes

- **Minimum Version**: macOS 11.0 (with compatibility shims for macOS 12.0+ features)
- **Concurrency**: Uses modern Swift async/await throughout
- **UI**: Pure SwiftUI with conditional compilation for version-specific features
