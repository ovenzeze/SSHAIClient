import Foundation

// MARK: - Unified Command Request/Response Schema
// This schema provides a consistent structure for AI interactions across all layers

/// Unified request structure for AI command generation
public struct AICommandRequest: Codable, Sendable {
    public let version: String = "1.0"
    public let requestId: String
    public let timestamp: Date
    public let input: Input
    public let context: Context
    public let options: Options
    
    public struct Input: Codable, Sendable {
        public let type: InputType
        public let content: String
        public let language: String // ISO 639-1 code: en, zh, ja, etc.
        
        public enum InputType: String, Codable, Sendable {
            case naturalLanguage = "natural_language"
            case directCommand = "direct_command"
            case mixedIntent = "mixed_intent"
        }
        
        public init(type: InputType = .naturalLanguage, content: String, language: String = "en") {
            self.type = type
            self.content = content
            self.language = language
        }
    }
    
    public struct Context: Codable, Sendable {
        public let system: SystemContext
        public let terminal: TerminalContext
        public let user: UserContext
        public let history: HistoryContext?
        
        public struct SystemContext: Codable, Sendable {
            public let os: String           // e.g., "Darwin", "Linux"
            public let osVersion: String    // e.g., "23.6.0"
            public let architecture: String // e.g., "arm64", "x86_64"
            public let hostname: String?
            public let kernelVersion: String?
            
            public init(os: String, osVersion: String, architecture: String, 
                       hostname: String? = nil, kernelVersion: String? = nil) {
                self.os = os
                self.osVersion = osVersion
                self.architecture = architecture
                self.hostname = hostname
                self.kernelVersion = kernelVersion
            }
        }
        
        public struct TerminalContext: Codable, Sendable {
            public let shell: String         // e.g., "zsh", "bash"
            public let shellVersion: String?
            public let workingDirectory: String
            public let environmentVariables: [String: String]?
            public let terminalType: String? // e.g., "xterm-256color"
            
            public init(shell: String, shellVersion: String? = nil, 
                       workingDirectory: String, environmentVariables: [String: String]? = nil,
                       terminalType: String? = nil) {
                self.shell = shell
                self.shellVersion = shellVersion
                self.workingDirectory = workingDirectory
                self.environmentVariables = environmentVariables
                self.terminalType = terminalType
            }
        }
        
        public struct UserContext: Codable, Sendable {
            public let username: String?
            public let userId: String?
            public let permissions: PermissionLevel?
            public let preferences: UserPreferences?
            
            public enum PermissionLevel: String, Codable, Sendable {
                case admin = "admin"
                case user = "user"
                case restricted = "restricted"
            }
            
            public struct UserPreferences: Codable, Sendable {
                public let preferSafeMode: Bool
                public let allowDestructiveCommands: Bool
                public let preferVerboseOutput: Bool
                public let customAliases: [String: String]?
                
                public init(preferSafeMode: Bool = true, 
                           allowDestructiveCommands: Bool = false,
                           preferVerboseOutput: Bool = false,
                           customAliases: [String: String]? = nil) {
                    self.preferSafeMode = preferSafeMode
                    self.allowDestructiveCommands = allowDestructiveCommands
                    self.preferVerboseOutput = preferVerboseOutput
                    self.customAliases = customAliases
                }
            }
            
            public init(username: String? = nil, userId: String? = nil,
                       permissions: PermissionLevel? = nil, preferences: UserPreferences? = nil) {
                self.username = username
                self.userId = userId
                self.permissions = permissions
                self.preferences = preferences
            }
        }
        
        public struct HistoryContext: Codable, Sendable {
            public let recentCommands: [String]
            public let sessionId: String?
            public let sessionStartTime: Date?
            
            public init(recentCommands: [String] = [], sessionId: String? = nil,
                       sessionStartTime: Date? = nil) {
                self.recentCommands = recentCommands
                self.sessionId = sessionId
                self.sessionStartTime = sessionStartTime
            }
        }
        
        public init(system: SystemContext, terminal: TerminalContext,
                   user: UserContext, history: HistoryContext? = nil) {
            self.system = system
            self.terminal = terminal
            self.user = user
            self.history = history
        }
    }
    
    public struct Options: Codable, Sendable {
        public let maxTokens: Int?
        public let temperature: Double?
        public let stream: Bool
        public let timeout: TimeInterval?
        public let model: String?
        
        public init(maxTokens: Int? = 500, temperature: Double? = 0.1,
                   stream: Bool = false, timeout: TimeInterval? = 30.0,
                   model: String? = nil) {
            self.maxTokens = maxTokens
            self.temperature = temperature
            self.stream = stream
            self.timeout = timeout
            self.model = model
        }
    }
    
    public init(requestId: String = UUID().uuidString, timestamp: Date = Date(),
               input: Input, context: Context, options: Options = Options()) {
        self.requestId = requestId
        self.timestamp = timestamp
        self.input = input
        self.context = context
        self.options = options
    }
}

/// Unified response structure from AI
public struct AICommandResponse: Codable, Sendable {
    public let version: String = "1.0"
    public let requestId: String
    public let timestamp: Date
    public let result: Result
    public let metadata: Metadata
    public let usage: Usage?
    
    public struct Result: Codable, Sendable {
        public let status: Status
        public let commands: [Command]?
        public let explanation: Explanation?
        public let error: ErrorInfo?
        
        public enum Status: String, Codable, Sendable {
            case success = "success"
            case partial = "partial"
            case error = "error"
            case needsClarification = "needs_clarification"
        }
        
        public struct Command: Codable, Sendable {
            public let id: String
            public let content: String
            public let type: CommandType
            public let risk: RiskAssessment
            public let alternatives: [Alternative]?
            public let dependencies: [String]? // Required commands/tools
            public let platforms: [String]?    // Supported platforms
            
            public enum CommandType: String, Codable, Sendable {
                case shell = "shell"
                case script = "script"
                case pipeline = "pipeline"
                case function = "function"
            }
            
            public struct RiskAssessment: Codable, Sendable {
                public let level: RiskLevel
                public let score: Double // 0.0 - 1.0
                public let factors: [String]
                public let warnings: [String]?
                public let requiresConfirmation: Bool
                
                public enum RiskLevel: String, Codable, Sendable {
                    case safe = "safe"
                    case low = "low"
                    case medium = "medium"
                    case high = "high"
                    case critical = "critical"
                }
                
                public init(level: RiskLevel, score: Double, factors: [String],
                           warnings: [String]? = nil, requiresConfirmation: Bool = false) {
                    self.level = level
                    self.score = score
                    self.factors = factors
                    self.warnings = warnings
                    self.requiresConfirmation = requiresConfirmation
                }
            }
            
            public struct Alternative: Codable, Sendable {
                public let command: String
                public let description: String
                public let tradeoffs: String?
                
                public init(command: String, description: String, tradeoffs: String? = nil) {
                    self.command = command
                    self.description = description
                    self.tradeoffs = tradeoffs
                }
            }
            
            public init(id: String = UUID().uuidString, content: String,
                       type: CommandType = .shell, risk: RiskAssessment,
                       alternatives: [Alternative]? = nil, dependencies: [String]? = nil,
                       platforms: [String]? = nil) {
                self.id = id
                self.content = content
                self.type = type
                self.risk = risk
                self.alternatives = alternatives
                self.dependencies = dependencies
                self.platforms = platforms
            }
        }
        
        public struct Explanation: Codable, Sendable {
            public let summary: String
            public let details: String?
            public let steps: [Step]?
            public let references: [String]? // URLs or man pages
            
            public struct Step: Codable, Sendable {
                public let order: Int
                public let description: String
                public let command: String?
                public let note: String?
                
                public init(order: Int, description: String, 
                           command: String? = nil, note: String? = nil) {
                    self.order = order
                    self.description = description
                    self.command = command
                    self.note = note
                }
            }
            
            public init(summary: String, details: String? = nil,
                       steps: [Step]? = nil, references: [String]? = nil) {
                self.summary = summary
                self.details = details
                self.steps = steps
                self.references = references
            }
        }
        
        public struct ErrorInfo: Codable, Sendable {
            public let code: String
            public let message: String
            public let type: ErrorType
            public let suggestions: [String]?
            
            public enum ErrorType: String, Codable, Sendable {
                case invalidInput = "invalid_input"
                case unsupported = "unsupported"
                case ambiguous = "ambiguous"
                case dangerous = "dangerous"
                case systemError = "system_error"
            }
            
            public init(code: String, message: String, type: ErrorType,
                       suggestions: [String]? = nil) {
                self.code = code
                self.message = message
                self.type = type
                self.suggestions = suggestions
            }
        }
        
        public init(status: Status, commands: [Command]? = nil,
                   explanation: Explanation? = nil, error: ErrorInfo? = nil) {
            self.status = status
            self.commands = commands
            self.explanation = explanation
            self.error = error
        }
    }
    
    public struct Metadata: Codable, Sendable {
        public let model: String
        public let provider: String
        public let confidence: Double // 0.0 - 1.0
        public let processingTime: TimeInterval
        public let cacheHit: Bool?
        public let tags: [String]?
        
        public init(model: String, provider: String, confidence: Double,
                   processingTime: TimeInterval, cacheHit: Bool? = nil, tags: [String]? = nil) {
            self.model = model
            self.provider = provider
            self.confidence = confidence
            self.processingTime = processingTime
            self.cacheHit = cacheHit
            self.tags = tags
        }
    }
    
    public struct Usage: Codable, Sendable {
        public let promptTokens: Int
        public let completionTokens: Int
        public let totalTokens: Int
        public let cost: Double? // In USD
        
        public init(promptTokens: Int, completionTokens: Int, totalTokens: Int, cost: Double? = nil) {
            self.promptTokens = promptTokens
            self.completionTokens = completionTokens
            self.totalTokens = totalTokens
            self.cost = cost
        }
    }
    
    public init(requestId: String, timestamp: Date = Date(),
               result: Result, metadata: Metadata, usage: Usage? = nil) {
        self.requestId = requestId
        self.timestamp = timestamp
        self.result = result
        self.metadata = metadata
        self.usage = usage
    }
}

// MARK: - JSON Encoding/Decoding Helpers

public extension AICommandRequest {
    /// Convert to JSON string
    func toJSON(prettyPrinted: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(self)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, EncodingError.Context(
                codingPath: [],
                debugDescription: "Failed to convert to UTF-8 string"
            ))
        }
        return jsonString
    }
    
    /// Create from JSON string
    static func fromJSON(_ jsonString: String) throws -> AICommandRequest {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid UTF-8 string"
            ))
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AICommandRequest.self, from: data)
    }
}

public extension AICommandResponse {
    /// Convert to JSON string
    func toJSON(prettyPrinted: Bool = false) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        let data = try encoder.encode(self)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, EncodingError.Context(
                codingPath: [],
                debugDescription: "Failed to convert to UTF-8 string"
            ))
        }
        return jsonString
    }
    
    /// Create from JSON string
    static func fromJSON(_ jsonString: String) throws -> AICommandResponse {
        guard let data = jsonString.data(using: .utf8) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: "Invalid UTF-8 string"
            ))
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AICommandResponse.self, from: data)
    }
}
