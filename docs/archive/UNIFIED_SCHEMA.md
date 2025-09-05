# Unified JSON Schema for AI Command Generation

## Overview

This document describes the unified JSON schema used throughout the SSH AI Client system for AI command generation requests and responses. This schema ensures consistency across all layers including API communication, database storage, and inter-service messaging.

## Design Principles

1. **Consistency**: Same structure used everywhere - API, database, cache, logs
2. **Completeness**: Captures all necessary context and metadata
3. **Extensibility**: Easy to add new fields without breaking existing code
4. **Type Safety**: Fully typed in Swift with Codable support
5. **Traceability**: Request IDs link requests and responses

## Schema Structure

### Request Schema (`AICommandRequest`)

```json
{
  "version": "1.0",
  "requestId": "uuid",
  "timestamp": "ISO8601",
  "input": {
    "type": "natural_language|direct_command|mixed_intent",
    "content": "user's input text",
    "language": "ISO 639-1 code"
  },
  "context": {
    "system": { /* OS details */ },
    "terminal": { /* Shell environment */ },
    "user": { /* Permissions and preferences */ },
    "history": { /* Recent commands */ }
  },
  "options": {
    "maxTokens": 500,
    "temperature": 0.1,
    "stream": false,
    "timeout": 30.0,
    "model": "specific-model-name"
  }
}
```

### Response Schema (`AICommandResponse`)

```json
{
  "version": "1.0",
  "requestId": "matching-request-uuid",
  "timestamp": "ISO8601",
  "result": {
    "status": "success|partial|error|needs_clarification",
    "commands": [ /* Array of command objects */ ],
    "explanation": { /* Detailed explanation */ },
    "error": { /* Error details if applicable */ }
  },
  "metadata": {
    "model": "model-name",
    "provider": "provider-name",
    "confidence": 0.95,
    "processingTime": 0.342,
    "cacheHit": false,
    "tags": ["category-tags"]
  },
  "usage": {
    "promptTokens": 245,
    "completionTokens": 189,
    "totalTokens": 434,
    "cost": 0.00087
  }
}
```

## Key Components

### 1. Input Types

- **`natural_language`**: "Show me all large files"
- **`direct_command`**: "ls -la | grep .log"
- **`mixed_intent`**: "Run ls but only show directories"

### 2. Risk Assessment

Five-level risk classification with scoring:

| Level | Score Range | Description | Example |
|-------|------------|-------------|---------|
| `safe` | 0.0-0.2 | Read-only operations | `ls`, `cat`, `grep` |
| `low` | 0.2-0.4 | Minor modifications | `touch`, `echo >>` |
| `medium` | 0.4-0.6 | Significant changes | `mv`, `cp -r` |
| `high` | 0.6-0.8 | Potentially destructive | `rm -r`, `chmod -R` |
| `critical` | 0.8-1.0 | System-critical operations | `rm -rf /`, `dd` |

### 3. Command Types

- **`shell`**: Single shell command
- **`script`**: Multi-line script
- **`pipeline`**: Commands connected with pipes
- **`function`**: Shell function definition

### 4. Status Codes

- **`success`**: Command generated successfully
- **`partial`**: Command generated but with limitations
- **`error`**: Cannot generate command due to error
- **`needs_clarification`**: Ambiguous request requiring user input

## Usage Examples

### Swift Implementation

```swift
// Create request
let request = AICommandRequest(
    input: AICommandRequest.Input(
        type: .naturalLanguage,
        content: "compress all log files",
        language: "en"
    ),
    context: AICommandRequest.Context(
        system: .init(
            os: "Darwin",
            osVersion: "23.6.0",
            architecture: "arm64"
        ),
        terminal: .init(
            shell: "zsh",
            workingDirectory: "/var/log"
        ),
        user: .init(
            permissions: .admin,
            preferences: .init(preferSafeMode: true)
        )
    )
)

// Send request
let client = UnifiedAIClient(config: config, apiKey: apiKey)
let response = try await client.generateCommand(request)

// Process response
switch response.result.status {
case .success:
    if let command = response.result.commands?.first {
        print("Command: \(command.content)")
        print("Risk: \(command.risk.level)")
    }
case .needsClarification:
    if let error = response.result.error {
        print("Clarification needed: \(error.message)")
    }
default:
    break
}
```

### Database Storage

```sql
-- Requests table
CREATE TABLE ai_requests (
    id TEXT PRIMARY KEY,
    request_id TEXT UNIQUE NOT NULL,
    timestamp DATETIME NOT NULL,
    input_json TEXT NOT NULL,
    context_json TEXT NOT NULL,
    options_json TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Responses table
CREATE TABLE ai_responses (
    id TEXT PRIMARY KEY,
    request_id TEXT NOT NULL,
    timestamp DATETIME NOT NULL,
    result_json TEXT NOT NULL,
    metadata_json TEXT NOT NULL,
    usage_json TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (request_id) REFERENCES ai_requests(request_id)
);
```

### API Integration

The schema is designed to work seamlessly with OpenAI-compatible APIs:

```swift
// Instruct AI to return structured JSON
let systemPrompt = """
Return ONLY valid JSON matching this structure:
{
  "result": { ... },
  "metadata": { ... }
}
"""

// AI returns partial response, client adds request metadata
let partialResponse = parseAIResponse(aiOutput)
let fullResponse = AICommandResponse(
    requestId: request.requestId,
    timestamp: Date(),
    result: partialResponse.result,
    metadata: enhanceMetadata(partialResponse.metadata),
    usage: calculateUsage(tokens)
)
```

## Benefits

### 1. Consistency Across Systems
- Same structure in API, database, cache, and logs
- No translation layers needed between components
- Reduced chance of data loss or corruption

### 2. Rich Context
- Full system and user context in every request
- Enables better command generation
- Supports personalization and learning

### 3. Complete Audit Trail
- Every request and response is tracked
- Request IDs link related operations
- Timestamps enable timeline reconstruction

### 4. Flexibility
- Optional fields for extensibility
- Version field for schema evolution
- Tags for categorization and filtering

## Migration Path

For existing systems using different schemas:

1. **Adapter Layer**: Create adapters to convert between schemas
2. **Dual Support**: Support both old and new schemas temporarily
3. **Gradual Migration**: Migrate components one at a time
4. **Deprecation**: Phase out old schema after full migration

## Best Practices

1. **Always include request ID** for traceability
2. **Validate JSON structure** before processing
3. **Store raw JSON** in database for future analysis
4. **Use schema version** to handle future changes
5. **Include error details** even in success responses (as warnings)
6. **Cache responses** based on request hash for performance

## Schema Evolution

The schema includes a version field to support future changes:

- **1.0**: Initial version (current)
- **1.1**: (Future) Add streaming support fields
- **2.0**: (Future) Major restructuring if needed

Backward compatibility is maintained by:
- Optional fields for new features
- Version-specific parsing logic
- Graceful degradation for missing fields

## Conclusion

This unified JSON schema provides a robust foundation for AI command generation across the SSH AI Client ecosystem. It ensures consistency, enables rich functionality, and supports future growth while maintaining backward compatibility.
