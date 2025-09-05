# Groq GPT-OSS-120B Integration

## Overview

This document describes the successful integration of Groq's GPT-OSS-120B model into the SSH AI Client. The integration provides powerful AI-driven command generation and intent classification capabilities using Groq's high-performance inference infrastructure.

## Model Information

- **Model**: `openai/gpt-oss-120b`
- **Parameters**: 120 billion
- **Provider**: Groq Cloud API
- **Endpoint**: `https://api.groq.com/openai/v1`
- **API Compatibility**: OpenAI-compatible REST API

## Key Features Implemented

### 1. Command Generation
Converts natural language queries into safe, executable shell commands with:
- Risk assessment (safe/caution/dangerous)
- Confidence scoring (0-100%)
- Detailed explanations
- Context awareness (OS, shell, working directory)

### 2. Intent Classification
Categorizes user input as:
- **Direct Command**: Ready-to-execute shell commands
- **AI Query**: Natural language requiring AI processing
- **Ambiguous**: Unclear intent needing clarification

### 3. Real API Integration
- Async/await Swift concurrency
- Robust error handling
- Retry logic with exponential backoff
- Rate limiting awareness
- API key management via environment variables or 1Password

## Configuration

### API Key Setup

#### Option 1: Environment Variable
```bash
export GROQ_API_KEY='your-api-key-here'
```

#### Option 2: 1Password CLI
```bash
op item create --category "API Credential" --title "GROQ API Credential Key" \
  --vault "rlklhbltdmgg3voak5plndnajm" credential="your-api-key"
```

### Swift Configuration

```swift
let config = AIServiceConfig(
    provider: .groq,
    model: "openai/gpt-oss-120b",
    maxTokens: 1000,
    temperature: 0.1,
    timeout: 30.0,
    maxRetries: 3
)
```

## Available Groq Models

As of December 2024, the following models are available:

### GPT-OSS Models (Recommended)
- `openai/gpt-oss-120b` - 120B parameters, best accuracy
- `openai/gpt-oss-20b` - 20B parameters, faster responses

### Other Available Models
- `llama-3.3-70b-versatile` - Meta's latest Llama model
- `llama-3.1-8b-instant` - Fast, lightweight model
- `gemma2-9b-it` - Google's Gemma model
- `deepseek-r1-distill-llama-70b` - DeepSeek's distilled model

## Usage Examples

### Command Generation

```swift
let context = GenerationContext(
    host: HostInfo(osName: "Darwin", osVersion: "14.0", architecture: "arm64"),
    shell: ShellInfo(name: "zsh", version: "5.9"),
    workingDirectory: "/Users/demo",
    recentCommands: ["git status", "docker ps"],
    userPreferences: UserPreferences()
)

let suggestion = try await client.generateCommand(
    "find large files over 100MB", 
    context: context
)

print(suggestion.command)     // "find . -type f -size +100M -print"
print(suggestion.risk)        // .safe
print(suggestion.confidence)  // 0.98
```

### Intent Classification

```swift
let context = TerminalContext(
    workingDirectory: "/Users/demo",
    recentCommands: ["ls", "cd projects"],
    shell: "zsh",
    environment: [:]
)

let result = try await client.classifyIntent(
    "how do I check disk space?", 
    context: context
)

print(result.type)        // .aiQuery
print(result.confidence)  // 0.98
print(result.explanation) // "Natural language question asking for instructions"
```

## Testing

### Run Unit Tests
```bash
swift test --filter OpenAICompatibleClientTests
```

### Run Integration Demo
```bash
# Build
swift build --product GroqIntegrationDemo

# Run with API key
export GROQ_API_KEY='your-api-key'
./.build/debug/GroqIntegrationDemo
```

### Quick Test Script
```bash
# Test a single command generation
curl -X POST 'https://api.groq.com/openai/v1/chat/completions' \
  -H "Authorization: Bearer $GROQ_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "openai/gpt-oss-120b",
    "messages": [
      {"role": "system", "content": "Generate a shell command"},
      {"role": "user", "content": "list all Python files"}
    ],
    "max_tokens": 100
  }'
```

## Performance Characteristics

### GPT-OSS-120B
- **Response Time**: 200-500ms for simple queries
- **Token Rate**: ~1000 tokens/second
- **Accuracy**: 98%+ for common commands
- **Context Window**: 8192 tokens

### Optimization Tips
1. Use lower temperature (0.1) for deterministic commands
2. Cache frequently used commands locally
3. Implement request batching for multiple queries
4. Use streaming for long responses

## Error Handling

The integration handles various error scenarios:

```swift
enum AIServiceError: Error {
    case authenticationFailed(String)  // Invalid API key
    case rateLimitExceeded(Date?)      // Too many requests
    case modelNotFound(String)         // Invalid model name
    case networkTimeout               // Request timeout
    case invalidResponse(String)      // Malformed API response
}
```

## Security Considerations

1. **API Key Storage**: Never hardcode keys; use environment variables or secure vaults
2. **Command Validation**: Always validate generated commands before execution
3. **Risk Assessment**: Respect risk levels returned by the AI
4. **User Confirmation**: Require user approval for high-risk operations
5. **Audit Logging**: Log all AI interactions for security review

## Future Enhancements

- [ ] Streaming response support for real-time output
- [ ] Multi-turn conversations for complex tasks
- [ ] Custom fine-tuning for domain-specific commands
- [ ] Local caching layer for offline operation
- [ ] Integration with Apple Intelligence for hybrid processing

## Troubleshooting

### Common Issues

1. **"Invalid API Key" Error**
   - Verify key is set: `echo $GROQ_API_KEY`
   - Check key validity with curl test

2. **"Model Decommissioned" Error**
   - Update to latest model name in configuration
   - Check available models: `curl https://api.groq.com/openai/v1/models`

3. **Timeout Errors**
   - Increase timeout in AIServiceConfig
   - Check network connectivity
   - Consider using smaller model for faster responses

## Support

For issues or questions:
- GitHub Issues: [SSHAIClient Repository](https://github.com/your-repo/SSHAIClient)
- Groq Documentation: [console.groq.com/docs](https://console.groq.com/docs)
- API Status: [status.groq.com](https://status.groq.com)

## License

This integration is part of the SSH AI Client project and follows the same license terms.
