# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-09-05

### Added
- **AI Engine**: Integrated Groq API with GPT-OSS-120B model for advanced command generation. (`#track-b`)
- **Unified JSON Schema**: Implemented a consistent data structure for all AI interactions. (`#track-b`)
- **SSH Core Implementation**: Added real SSH connection management using SwiftNIO. (`#track-a`)
- **1Password Integration**: Added capability to fetch secrets from 1Password.
- **Technical Specification**: Created `TECHNICAL_SPECIFICATION.md` to define coding standards and architecture guidelines.
- **Automated Code Review**: Added a Swift script and Git hook to automate code quality checks.

### Changed
- **Architecture**: Refactored to a protocol-based, dependency-injected architecture.
- **Data Persistence**: Placeholder `LocalDataManager` is ready for SQLite implementation. (`#track-c`)
- **UI/UX**: Migrated to a more robust connection management UI. (`#track-d`)

### Fixed
- **Build Errors**: Resolved numerous compilation errors, including type name collisions (`SSHConnection`).
- **Platform Compatibility**: Addressed SwiftUI API availability issues for macOS 11.0+.
- **Security**: Moved secret storage from `UserDefaults` to the system Keychain.


