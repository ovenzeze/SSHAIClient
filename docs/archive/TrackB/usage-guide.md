# AI Client Usage Guide

## Quick Setup

### 1. Install 1Password CLI
```bash
brew install 1password-cli
```

### 2. Sign in to 1Password
```bash
op signin
```

### 3. Create API Key Items in 1Password

For **Groq** (default, recommended):
```bash
op item create --category="API Credential" --title="Groq API Key" \
    credential="your-groq-api-key-here" \
    --notes="Groq API key for SSHAIClient - Free tier available"
```

For **OpenAI** (optional):
```bash
op item create --category="API Credential" --title="OpenAI API Key" \
    credential="sk-your-openai-key" \
    --notes="OpenAI API key for SSHAIClient"
```

For **Anthropic Claude** (optional):
```bash
op item create --category="API Credential" --title="Anthropic Claude API Key" \
    credential="sk-ant-your-claude-key" \
    --notes="Anthropic Claude API key for SSHAIClient"
```

### 4. Get a Free Groq API Key
1. Visit [Groq Console](https://console.groq.com/)
2. Sign up for a free account
3. Navigate to "API Keys" section
4. Create a new API key
5. Copy the key (starts with `gsk_`)

## Basic Usage

### Import and Initialize
```swift
import SSHAIClient

// Use default Groq configuration
let aiClient = OpenAICompatibleClient()

// Or customize the configuration
let config = AIServiceConfig(
    provider: .groq,
    model: "llama3-70b-8192",
    temperature: 0.1,
    maxTokens: 1000
)
let customClient = OpenAICompatibleClient(config: config)
```

### Generate Commands
```swift
// Create context
let context = GenerationContext(
    host: HostInfo(osName: "Darwin", osVersion: "14.0", architecture: "arm64"),
    shell: ShellInfo(name: "zsh", version: "5.8"),
    workingDirectory: "/Users/developer/project",
    recentCommands: ["pwd", "ls -la"],
    userPreferences: UserPreferences()
)

// Generate command from natural language
do {
    let suggestion = try await aiClient.generateCommand(
        "show me all git branches",
        context: context
    )
    
    print("Command: \(suggestion.command)")
    print("Explanation: \(suggestion.explanation)")
    print("Risk Level: \(suggestion.risk)")
    print("Confidence: \(suggestion.confidence)")
} catch {
    print("Error: \(error)")
}
```

### Classify User Intent
```swift
let terminalContext = TerminalContext(
    workingDirectory: "/Users/developer",
    recentCommands: ["ls", "cd project"],
    shell: "zsh"
)

do {
    let intent = try await aiClient.classifyIntent(
        "show me files",
        context: terminalContext
    )
    
    switch intent.type {
    case .command:
        print("Direct command detected")
    case .aiQuery:
        print("Natural language query - needs AI processing")
    case .ambiguous:
        print("Unclear intent - needs clarification")
    }
} catch {
    print("Classification error: \(error)")
}
```

## Provider Comparison

| Provider | Speed | Cost | Quality | Free Tier |
|----------|-------|------|---------|-----------|
| **Groq** (Default) | 🚀 Very Fast | 💚 Free | ⭐ Good | ✅ Generous |
| OpenAI GPT-4 | 🐌 Moderate | 💰 Expensive | ⭐⭐⭐ Excellent | ❌ Paid Only |
| Claude 3 | 🚶 Slow | 💸 Moderate | ⭐⭐ Very Good | ✅ Limited |
| Ollama | 🚀 Fast | 💚 Free | ⭐ Variable | ✅ Unlimited |

### Why Groq is Default
- **Fastest inference**: Sub-second response times
- **Free tier**: Generous usage limits
- **Good quality**: Llama 3 70B performs well for command generation
- **Reliable**: High availability and uptime

## Configuration Examples

### Switch to OpenAI
```swift
let openAIConfig = AIServiceConfig(provider: .openai)
let openAIClient = OpenAICompatibleClient(config: openAIConfig)
```

### Use Local Ollama
```swift
let ollamaConfig = AIServiceConfig(
    provider: .ollama,
    baseURL: "http://localhost:11434/v1",
    model: "codellama"
)
let ollamaClient = OpenAICompatibleClient(config: ollamaConfig)
```

### Custom Provider
```swift
let customConfig = AIServiceConfig(
    provider: .custom,
    baseURL: "https://your-ai-api.com/v1",
    model: "your-model",
    temperature: 0.0,
    maxTokens: 500
)
```

## Error Handling

```swift
do {
    let result = try await aiClient.generateCommand("your query", context: context)
    // Success
} catch AIServiceError.authenticationFailed(let details) {
    print("Check your API key: \(details)")
} catch AIServiceError.rateLimitExceeded(let resetTime) {
    print("Rate limited until: \(resetTime)")
} catch AIServiceError.networkTimeout {
    print("Request timed out - check your connection")
} catch {
    print("Unexpected error: \(error)")
}
```

## Environment Variable Fallback

If 1Password is not available, the client will fallback to environment variables:

```bash
# For Groq
export GROQ_API_KEY="gsk_your_key_here"

# For OpenAI  
export OPENAI_API_KEY="sk-your_key_here"

# For Claude
export ANTHROPIC_API_KEY="sk-ant-your_key_here"
```

## Testing Connection

```swift
// Test if AI service is working
do {
    let isWorking = try await aiClient.testConnection()
    print("AI service is \(isWorking ? "working" : "not available")")
} catch {
    print("Connection test failed: \(error)")
}

// Check rate limits
if let rateLimit = await aiClient.getRateLimit() {
    print("Requests remaining: \(rateLimit.requestsRemaining)")
    print("Reset time: \(rateLimit.resetTime)")
}
```

## Best Practices

### 1. Context Matters
Always provide rich context for better command generation:
```swift
let context = GenerationContext(
    host: HostInfo(osName: "Linux", osVersion: "Ubuntu 22.04", architecture: "x86_64"),
    shell: ShellInfo(name: "bash", version: "5.1"),
    workingDirectory: "/home/user/webapp",
    recentCommands: ["npm install", "git status", "docker ps"],
    environment: ["NODE_ENV": "development"]
)
```

### 2. Handle Errors Gracefully
```swift
func generateCommandSafely(_ query: String) async -> CommandSuggestion {
    do {
        return try await aiClient.generateCommand(query, context: context)
    } catch {
        // Fallback to basic rule-based generation
        return CommandSuggestion(
            command: "# AI service unavailable",
            explanation: "Try: \(query)",
            risk: .safe,
            confidence: 0.1
        )
    }
}
```

### 3. Respect Rate Limits
```swift
if let rateLimit = await aiClient.getRateLimit(),
   rateLimit.requestsRemaining < 5 {
    print("Low on API calls, consider caching or local processing")
}
```

### 4. Use Appropriate Temperature
- **0.0-0.2**: Deterministic, good for command generation
- **0.3-0.7**: Balanced, good for explanations  
- **0.8-1.0**: Creative, avoid for shell commands

## Troubleshooting

### Common Issues

**"1Password CLI not found"**
```bash
brew install 1password-cli
op signin
```

**"API key invalid"**
- Check the API key in 1Password
- Ensure it's not expired
- Verify provider-specific format

**"Rate limit exceeded"**
- Wait for reset time
- Switch to different provider
- Implement caching

**"Model not found"**
- Check provider documentation for available models
- Update model name in configuration

### Debug Mode
```swift
// Enable verbose logging (in development)
// ⚠️ SECURITY WARNING: Never enable verbose logging in production environments
// as it may expose sensitive data like API keys and user inputs in logs
let config = AIServiceConfig(
    provider: .groq,
    timeout: 60.0,  // Longer timeout for debugging
    maxRetries: 1   // Fewer retries to see errors faster
)
```

This completes the basic usage guide. The AI client is now ready for integration into the SSHAIClient application!
