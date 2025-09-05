# AI Engine Architecture Design

**Version:** 1.0  
**Date:** 2025-09-05  
**Track:** B (AI Engine Enhancement)  
**Status:** Design Phase

---

## 🎯 Vision & Objectives

Transform SSHAIClient from rule-based command generation to a sophisticated AI-powered engine that provides:
- **Intelligent Command Generation**: Natural language to shell commands with 90%+ accuracy
- **Context-Aware Assistance**: Leverages terminal history, current directory, and user preferences
- **Multi-Modal AI**: Local-first with cloud fallback for optimal privacy and performance
- **Personalized Learning**: Adapts to individual user patterns and command preferences
- **Safety-First Design**: Built-in risk assessment and dangerous command protection

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        AI Engine Architecture                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐ │
│  │   UI Layer      │    │  TerminalView   │    │   Settings   │ │
│  │  (SwiftUI)      │    │    Model        │    │    Panel     │ │
│  └─────────────────┘    └─────────────────┘    └──────────────┘ │
│           │                       │                     │       │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                 AIServiceManager                            │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │  Provider   │  │ Rate Limit  │  │   Configuration     │ │ │
│  │  │  Registry   │  │  Manager    │  │     Manager         │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│           │                                                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              HybridIntentClassifier                        │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │ Local Cache │  │ Rule Engine │  │  Context Analyzer   │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│           │                                                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │               Command Generation Layer                      │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │ Enhanced    │  │ Device AI   │  │   Remote AI         │ │ │
│  │  │ Rules       │  │ Generator   │  │   Generator         │ │ │
│  │  │ Generator   │  │ (Core ML)   │  │ (OpenAI/Claude)     │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│           │                                                     │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              Personalization Layer                         │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │ │
│  │  │ Command     │  │ User Model  │  │  Learning Engine    │ │ │
│  │  │ History     │  │  Manager    │  │    (SQLite)         │ │ │
│  │  └─────────────┘  └─────────────┘  └─────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔌 Core Protocol Design

### 1. AIServiceManaging Protocol

```swift
public protocol AIServiceManaging: Sendable {
    /// Service identification
    var name: String { get }
    var version: String { get }
    var provider: AIProvider { get }
    
    /// Core AI capabilities
    func classifyIntent(_ input: String, context: TerminalContext) async throws -> IntentResult
    func generateCommand(_ query: String, context: GenerationContext) async throws -> CommandSuggestion
    
    /// Service management
    func isAvailable() async -> Bool
    func testConnection() async throws -> Bool
    func getRateLimit() async -> RateLimit?
    
    /// Configuration
    func configure(with config: AIServiceConfig) async throws
    func supportedLanguages() -> [String]
}
```

### 2. Enhanced Command Generation

```swift
public protocol AdvancedCommandGenerating: CommandGenerating {
    /// Enhanced pattern matching
    func generateWithPatterns(_ query: String, context: GenerationContext) async throws -> [CommandSuggestion]
    
    /// Context-aware generation
    func generateContextual(_ query: String, context: GenerationContext) async throws -> CommandSuggestion
    
    /// Learning integration
    func learnFromFeedback(_ original: CommandSuggestion, corrected: String, accepted: Bool) async
    
    /// Batch processing
    func generateBatch(_ queries: [String], context: GenerationContext) async throws -> [CommandSuggestion]
}
```

### 3. Personalization Protocol

```swift
public protocol PersonalizationManaging: Sendable {
    /// User modeling
    func updateUserModel(from command: String, context: GenerationContext, successful: Bool) async
    func getUserPreferences() async -> UserAIPreferences
    func setUserPreferences(_ preferences: UserAIPreferences) async
    
    /// Command learning
    func recordCommandUsage(_ command: String, frequency: Int, lastUsed: Date) async
    func getFrequentCommands(limit: Int) async -> [CommandFrequency]
    
    /// Personalized suggestions
    func personalizedSuggestions(for query: String, context: GenerationContext) async -> [CommandSuggestion]
}
```

---

## 📚 Expanded Rule Catalogue

### Git Operations (30+ patterns)

```swift
struct GitCommandPatterns {
    // Repository management
    "initialize git repository" → "git init"
    "clone repository from <url>" → "git clone {url}"
    "add remote origin <url>" → "git remote add origin {url}"
    
    // Staging and commits
    "add all files" → "git add ."
    "commit with message <msg>" → "git commit -m \"{msg}\""
    "amend last commit" → "git commit --amend"
    
    // Branch operations
    "create new branch <name>" → "git checkout -b {name}"
    "switch to branch <name>" → "git checkout {name}"
    "merge branch <name>" → "git merge {name}"
    "delete branch <name>" → "git branch -d {name}"
    
    // Status and history
    "check git status" → "git status"
    "show commit history" → "git log --oneline"
    "show file differences" → "git diff"
    
    // Remote operations
    "push to remote" → "git push origin HEAD"
    "pull from remote" → "git pull origin main"
    "fetch updates" → "git fetch --all"
    
    // Advanced operations
    "stash changes" → "git stash"
    "apply stashed changes" → "git stash pop"
    "reset to commit <hash>" → "git reset --hard {hash}" // Risk: dangerous
    "rebase interactive" → "git rebase -i HEAD~3" // Risk: caution
}
```

### Docker Operations (25+ patterns)

```swift
struct DockerCommandPatterns {
    // Container lifecycle
    "list running containers" → "docker ps"
    "list all containers" → "docker ps -a"
    "run container <image>" → "docker run -it {image}"
    "start container <name>" → "docker start {name}"
    "stop container <name>" → "docker stop {name}"
    "remove container <name>" → "docker rm {name}"
    
    // Image management
    "list docker images" → "docker images"
    "pull image <name>" → "docker pull {name}"
    "build image from dockerfile" → "docker build -t {tag} ."
    "remove image <name>" → "docker rmi {name}"
    
    // Docker compose
    "start docker compose" → "docker-compose up -d"
    "stop docker compose" → "docker-compose down"
    "rebuild compose services" → "docker-compose up --build"
    
    // System operations
    "show docker system info" → "docker info"
    "cleanup unused resources" → "docker system prune" // Risk: caution
    "show container logs <name>" → "docker logs {name}"
}
```

### Kubernetes Operations (20+ patterns)

```swift
struct KubernetesCommandPatterns {
    // Cluster info
    "get cluster info" → "kubectl cluster-info"
    "get all nodes" → "kubectl get nodes"
    "describe node <name>" → "kubectl describe node {name}"
    
    // Pod management
    "get all pods" → "kubectl get pods"
    "describe pod <name>" → "kubectl describe pod {name}"
    "get pod logs <name>" → "kubectl logs {name}"
    "delete pod <name>" → "kubectl delete pod {name}"
    
    // Service management
    "get all services" → "kubectl get services"
    "expose deployment <name>" → "kubectl expose deployment {name} --port=80"
    
    // Namespace operations
    "get all namespaces" → "kubectl get namespaces"
    "switch namespace <name>" → "kubectl config set-context --current --namespace={name}"
    
    // Deployment management
    "get deployments" → "kubectl get deployments"
    "scale deployment <name> <replicas>" → "kubectl scale deployment {name} --replicas={replicas}"
    "rollout restart <name>" → "kubectl rollout restart deployment/{name}"
}
```

### System Administration (35+ patterns)

```swift
struct SystemAdminPatterns {
    // Process management
    "kill process by name <name>" → "pkill {name}" // Risk: caution
    "kill process by pid <pid>" → "kill {pid}" // Risk: caution
    "force kill process <pid>" → "kill -9 {pid}" // Risk: dangerous
    "show process tree" → "pstree"
    
    // Service management (systemctl)
    "start service <name>" → "systemctl start {name}" // Risk: caution
    "stop service <name>" → "systemctl stop {name}" // Risk: caution
    "restart service <name>" → "systemctl restart {name}" // Risk: caution
    "enable service <name>" → "systemctl enable {name}"
    "disable service <name>" → "systemctl disable {name}"
    "check service status <name>" → "systemctl status {name}"
    "reload systemd daemon" → "systemctl daemon-reload"
    
    // Disk and filesystem
    "show disk usage" → "df -h"
    "show directory size" → "du -sh *"
    "mount filesystem <device> <mountpoint>" → "mount {device} {mountpoint}" // Risk: caution
    "unmount filesystem <path>" → "umount {path}" // Risk: caution
    
    // Network tools
    "check network connectivity <host>" → "ping {host}"
    "download file <url>" → "curl -O {url}"
    "download with wget <url>" → "wget {url}"
    "check open ports" → "netstat -tulpn"
    "show network interfaces" → "ip addr show"
    
    // Package management (based on context detection)
    "update package list" → "brew update" / "sudo apt update" / "sudo yum update"
    "install package <name>" → "brew install {name}" / "sudo apt install {name}"
    "search for package <name>" → "brew search {name}" / "apt search {name}"
}
```

### Text Processing & Search (25+ patterns)

```swift
struct TextProcessingPatterns {
    // File searching
    "find files named <pattern>" → "find . -name \"{pattern}\""
    "find files containing <text>" → "grep -r \"{text}\" ."
    "find large files" → "find . -type f -size +100M"
    
    // Text manipulation
    "search in file <pattern> <file>" → "grep \"{pattern}\" {file}"
    "replace text <old> <new> <file>" → "sed -i 's/{old}/{new}/g' {file}" // Risk: caution
    "count lines in file <file>" → "wc -l {file}"
    "show file head <file>" → "head {file}"
    "show file tail <file>" → "tail {file}"
    "follow file changes <file>" → "tail -f {file}"
    
    // Text processing
    "sort file contents <file>" → "sort {file}"
    "remove duplicate lines <file>" → "sort {file} | uniq"
    "column statistics <file>" → "awk '{print NF}' {file} | sort | uniq -c"
}
```

---

## 🧠 AI Integration Strategy

### 1. Local-First Approach

```swift
public enum AIStrategy {
    case localOnly          // Rules + Core ML only
    case hybridPreferred    // Local first, cloud fallback
    case cloudPreferred     // Cloud first, local fallback
    case cloudOnly          // Remote APIs only
}

public struct AIServiceConfig {
    let strategy: AIStrategy
    let maxLatency: TimeInterval
    let privacyLevel: PrivacyLevel
    let fallbackBehavior: FallbackBehavior
}
```

### 2. Apple Intelligence Integration

```swift
@available(macOS 15.0, *)
public final class DeviceAICommandGenerator: AdvancedCommandGenerating {
    private let intentClassifier: MLModel
    private let commandGenerator: MLModel
    
    public func generateWithAppleIntelligence(_ query: String, context: GenerationContext) async throws -> CommandSuggestion {
        // Use Apple's Intelligence APIs for on-device processing
        let intent = try await classifyIntentCoreML(query, context: context)
        let command = try await generateCommandCoreML(query, intent: intent, context: context)
        
        return CommandSuggestion(
            command: command.text,
            explanation: command.explanation,
            risk: assessRisk(command.text),
            confidence: command.confidence
        )
    }
}
```

### 3. Remote AI Integration

```swift
public final class RemoteAICommandGenerator: AdvancedCommandGenerating {
    private let httpClient: HTTPClient
    private let provider: AIProvider
    
    public enum AIProvider: CaseIterable {
        case openai
        case claude
        case custom(baseURL: URL)
        
        var name: String {
            switch self {
            case .openai: return "OpenAI GPT-4"
            case .claude: return "Anthropic Claude"
            case .custom: return "Custom AI"
            }
        }
    }
    
    public func generateWithRemoteAI(_ query: String, context: GenerationContext) async throws -> CommandSuggestion {
        let prompt = buildContextualPrompt(query: query, context: context)
        let response = try await sendAIRequest(prompt: prompt)
        return parseAIResponse(response)
    }
}
```

---

## 💾 Personalization & Learning System

### 1. SQLite Schema Design

```sql
-- User command patterns and preferences
CREATE TABLE command_history (
    id INTEGER PRIMARY KEY,
    command TEXT NOT NULL,
    query TEXT,
    context_hash TEXT,
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
    success BOOLEAN DEFAULT TRUE,
    user_rating INTEGER CHECK (user_rating >= 1 AND user_rating <= 5)
);

-- Command frequency tracking
CREATE TABLE command_frequency (
    command_pattern TEXT PRIMARY KEY,
    usage_count INTEGER DEFAULT 0,
    last_used DATETIME DEFAULT CURRENT_TIMESTAMP,
    avg_success_rate REAL DEFAULT 1.0
);

-- User preferences and AI settings
CREATE TABLE user_preferences (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Context-aware command mapping
CREATE TABLE context_commands (
    id INTEGER PRIMARY KEY,
    directory_pattern TEXT,
    shell_type TEXT,
    recommended_command TEXT,
    frequency INTEGER DEFAULT 0
);

-- AI service performance metrics
CREATE TABLE ai_service_metrics (
    provider TEXT,
    date DATE,
    requests_count INTEGER DEFAULT 0,
    avg_latency REAL,
    success_rate REAL,
    PRIMARY KEY (provider, date)
);
```

### 2. Learning Algorithm

```swift
public final class CommandLearningEngine: PersonalizationManaging {
    private let database: SQLiteDatabase
    
    public func updateUserModel(from command: String, context: GenerationContext, successful: Bool) async {
        // Update command frequency
        await updateCommandFrequency(command, successful: successful)
        
        // Update context-specific patterns
        await updateContextualPatterns(command: command, context: context)
        
        // Update user success patterns
        await updateSuccessPatterns(command: command, success: successful)
    }
    
    public func personalizedSuggestions(for query: String, context: GenerationContext) async -> [CommandSuggestion] {
        // Get user's historical patterns
        let userPatterns = await getUserCommandPatterns(query: query)
        
        // Consider context-specific history
        let contextual = await getContextualSuggestions(context: context)
        
        // Combine with frequency-based recommendations
        let frequent = await getFrequentCommandsForQuery(query)
        
        return mergeAndRankSuggestions([userPatterns, contextual, frequent])
    }
}
```

---

## ⚡ Hybrid Execution Flow

### 1. Request Processing Pipeline

```swift
public final class HybridAIProcessor {
    private let ruleGenerator: EnhancedRuleCommandGenerator
    private let deviceAI: DeviceAICommandGenerator?
    private let remoteAI: RemoteAICommandGenerator
    private let cache: AIResponseCache
    
    public func process(_ query: String, context: GenerationContext) async throws -> CommandSuggestion {
        // Step 1: Check cache
        if let cached = await cache.get(query: query, context: context) {
            return cached
        }
        
        // Step 2: Try enhanced rules (fast, accurate for known patterns)
        if let ruleBased = try await ruleGenerator.generateFast(query, context: context),
           ruleBased.confidence > 0.8 {
            await cache.store(query: query, context: context, result: ruleBased)
            return ruleBased
        }
        
        // Step 3: Try device AI (private, medium latency)
        if let deviceAI = deviceAI,
           await deviceAI.isAvailable() {
            do {
                let deviceResult = try await deviceAI.generateWithAppleIntelligence(query, context: context)
                if deviceResult.confidence > 0.7 {
                    await cache.store(query: query, context: context, result: deviceResult)
                    return deviceResult
                }
            } catch {
                // Continue to remote AI
            }
        }
        
        // Step 4: Use remote AI (highest capability, higher latency)
        let remoteResult = try await remoteAI.generateWithRemoteAI(query, context: context)
        await cache.store(query: query, context: context, result: remoteResult)
        
        return remoteResult
    }
}
```

### 2. Error Handling & Graceful Degradation

```swift
public struct AIServiceError: Error {
    public enum ErrorType {
        case networkTimeout
        case rateLimitExceeded
        case apiKeyInvalid
        case serviceUnavailable
        case contextInsufficient
        case queryTooComplex
    }
    
    let type: ErrorType
    let underlyingError: Error?
    let suggestedFallback: CommandSuggestion?
}

public final class GracefulFallbackManager {
    public func handleError(_ error: AIServiceError, 
                          originalQuery: String, 
                          context: GenerationContext) async -> CommandSuggestion {
        switch error.type {
        case .networkTimeout, .serviceUnavailable:
            // Fall back to rules-only generation
            return try await ruleGenerator.generate(query: originalQuery, context: context)
            
        case .rateLimitExceeded:
            // Use cached similar queries or basic command
            return await findSimilarCachedQuery(originalQuery) ?? createFallbackSuggestion(originalQuery)
            
        case .apiKeyInvalid:
            // Disable remote AI, use local only
            await configuration.setStrategy(.localOnly)
            return try await processWithLocalOnly(originalQuery, context: context)
            
        default:
            return error.suggestedFallback ?? createFallbackSuggestion(originalQuery)
        }
    }
}
```

---

## 🔒 Security & Privacy Design

### 1. API Key Management

```swift
public final class SecureKeyManager {
    private let onePasswordCLI: OnePasswordCLI
    
    public func getAPIKey(for provider: AIProvider) async throws -> String {
        switch provider {
        case .openai:
            return try await onePasswordCLI.getSecret("OPENAI_API_KEY")
        case .claude:
            return try await onePasswordCLI.getSecret("ANTHROPIC_API_KEY")
        case .custom:
            return try await onePasswordCLI.getSecret("CUSTOM_AI_API_KEY")
        }
    }
    
    public func rotateAPIKey(for provider: AIProvider) async throws {
        // Implement key rotation logic
    }
}
```

### 2. Privacy Controls

```swift
public struct PrivacyConfig {
    let sendContextToRemoteAI: Bool
    let cacheRemoteResponses: Bool
    let logAIInteractions: Bool
    let shareUsageAnalytics: Bool
    let maxContextSharingLevel: ContextSharingLevel
}

public enum ContextSharingLevel {
    case none           // No context shared
    case minimal        // Only query text
    case standard       // Query + basic context (directory, shell)
    case full           // All available context
}
```

---

## 📊 Performance & Caching Strategy

### 1. Multi-Level Caching

```swift
public final class AIResponseCache {
    private let memoryCache: NSCache<NSString, CachedResponse>
    private let diskCache: SQLiteCache
    
    // Memory cache for immediate reuse (100 entries, 5-minute TTL)
    // Disk cache for session persistence (1000 entries, 24-hour TTL)
    // Contextual cache considering directory and recent commands
    
    public func get(query: String, context: GenerationContext) async -> CommandSuggestion? {
        let cacheKey = generateCacheKey(query: query, context: context)
        
        // Check memory cache first (fastest)
        if let memoryResult = memoryCache.object(forKey: cacheKey as NSString) {
            return memoryResult.suggestion
        }
        
        // Check disk cache (fast)
        if let diskResult = await diskCache.get(key: cacheKey) {
            // Promote to memory cache
            memoryCache.setObject(diskResult, forKey: cacheKey as NSString)
            return diskResult.suggestion
        }
        
        return nil
    }
}
```

### 2. Performance Monitoring

```swift
public final class AIPerformanceMonitor {
    public struct Metrics {
        let averageLatency: TimeInterval
        let cacheHitRate: Double
        let successRate: Double
        let providerUsage: [AIProvider: Int]
    }
    
    public func recordRequest(_ provider: AIProvider, latency: TimeInterval, success: Bool) async
    public func getMetrics(timeframe: TimeInterval) async -> Metrics
    public func optimizeProviderSelection() async -> AIProvider
}
```

---

## 🧪 Testing Strategy

### 1. Unit Testing Framework

```swift
// Mock AI providers for testing
public final class MockAIProvider: AIServiceManaging {
    public var stubbedResults: [String: CommandSuggestion] = [:]
    public var simulatedLatency: TimeInterval = 0.1
    public var shouldFailRequests: Bool = false
    
    public func generateCommand(_ query: String, context: GenerationContext) async throws -> CommandSuggestion {
        if shouldFailRequests {
            throw AIServiceError(type: .serviceUnavailable, underlyingError: nil, suggestedFallback: nil)
        }
        
        await Task.sleep(nanoseconds: UInt64(simulatedLatency * 1_000_000_000))
        
        return stubbedResults[query] ?? CommandSuggestion(
            command: "echo 'Mock command for: \(query)'",
            explanation: "Mock explanation",
            risk: .safe,
            confidence: 0.8
        )
    }
}

// Integration test scenarios
public final class AIIntegrationTests: XCTestCase {
    func testHybridFallbackBehavior() async throws {
        // Test local → device → remote fallback chain
    }
    
    func testPersonalizationLearning() async throws {
        // Test that user corrections improve future suggestions
    }
    
    func testCacheEffectiveness() async throws {
        // Test cache hit rates and performance improvements
    }
}
```

---

## 📈 Success Metrics & KPIs

### Development Metrics
- **Code Coverage**: >95% for new AI components
- **Performance**: <200ms for rule-based, <500ms for AI-enhanced
- **Test Coverage**: All AI providers must have comprehensive mocks

### User Experience Metrics  
- **Command Accuracy**: >90% for common patterns, >70% for complex queries
- **User Satisfaction**: >4.5/5 rating for AI suggestions
- **Learning Effectiveness**: 20% improvement in suggestion quality after 100 interactions

### Technical Metrics
- **Cache Hit Rate**: >60% for repeated queries
- **API Cost Efficiency**: <$0.01 per command generation
- **Privacy Compliance**: 100% of sensitive context stays local

---

## 🚀 Implementation Timeline

### Week 1-2: Foundation
- [x] Architecture design and documentation
- [ ] Enhanced rule engine with 100+ patterns
- [ ] Basic caching and performance monitoring
- [ ] Expanded unit tests

### Week 3-4: AI Integration
- [ ] Apple Intelligence integration (macOS 15+)
- [ ] Remote AI service wrappers (OpenAI/Claude)  
- [ ] Hybrid processing pipeline
- [ ] Error handling and fallback mechanisms

### Week 5-6: Personalization
- [ ] SQLite personalization database
- [ ] Command learning and frequency tracking
- [ ] User preference management
- [ ] Performance optimization and caching

### Week 7: Polish & Testing
- [ ] Comprehensive integration testing
- [ ] Performance benchmarking
- [ ] Security audit
- [ ] Documentation and PR preparation

---

## 💡 Future Enhancements

### Phase 2 Features (Post-MVP)
- **Multi-language Support**: Spanish, French, German command generation
- **Voice Commands**: Siri integration for hands-free operation
- **Team Learning**: Shared command patterns across organization
- **Advanced Context**: Git repository awareness, Docker environment detection
- **Custom Models**: Fine-tuned models for specific environments/workflows

This design provides a solid foundation for transforming SSHAIClient into an intelligent, context-aware AI assistant while maintaining the excellent architectural principles already established in the codebase.
