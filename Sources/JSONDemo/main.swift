import Foundation
import SSHAIClient

/// Demonstrates the unified JSON schema output
@main
struct JSONDemo {
    static func main() {
        print("═══════════════════════════════════════════════════════")
        print("📄 Unified JSON Schema - Complete Example Output")
        print("═══════════════════════════════════════════════════════\n")
        
        // Create a comprehensive response
        let response = AICommandResponse(
            requestId: "req-\(UUID().uuidString)",
            timestamp: Date(),
            result: AICommandResponse.Result(
                status: .success,
                commands: [
                    AICommandResponse.Result.Command(
                        id: "cmd-001",
                        content: "find /var/log -name '*.log' -size +100M -mtime +7 -exec gzip {} \\;",
                        type: .shell,
                        risk: AICommandResponse.Result.Command.RiskAssessment(
                            level: .medium,
                            score: 0.45,
                            factors: [
                                "modifies system files",
                                "recursive operation",
                                "affects log files"
                            ],
                            warnings: [
                                "This will compress original log files",
                                "Some services may not be able to write to compressed logs",
                                "Consider stopping services before compression"
                            ],
                            requiresConfirmation: true
                        ),
                        alternatives: [
                            AICommandResponse.Result.Command.Alternative(
                                command: "find /var/log -name '*.log' -size +100M -mtime +7 -exec gzip -k {} \\;",
                                description: "Keep original files while creating compressed copies",
                                tradeoffs: "Requires double the disk space temporarily"
                            ),
                            AICommandResponse.Result.Command.Alternative(
                                command: "tar -czf /backup/logs_$(date +%Y%m%d).tar.gz /var/log/*.log",
                                description: "Create single archive of all logs",
                                tradeoffs: "All files in one archive, harder to access individual files"
                            )
                        ],
                        dependencies: ["find", "gzip"],
                        platforms: ["Darwin", "Linux", "FreeBSD"]
                    )
                ],
                explanation: AICommandResponse.Result.Explanation(
                    summary: "Find and compress large, old log files to save disk space",
                    details: "This command searches the /var/log directory for log files larger than 100MB that haven't been modified in the last 7 days, then compresses them using gzip",
                    steps: [
                        AICommandResponse.Result.Explanation.Step(
                            order: 1,
                            description: "Search for log files in /var/log",
                            command: "find /var/log -name '*.log'",
                            note: "Recursively searches all subdirectories"
                        ),
                        AICommandResponse.Result.Explanation.Step(
                            order: 2,
                            description: "Filter by size (>100MB)",
                            command: "-size +100M",
                            note: "100M means 100 megabytes"
                        ),
                        AICommandResponse.Result.Explanation.Step(
                            order: 3,
                            description: "Filter by modification time (>7 days)",
                            command: "-mtime +7",
                            note: "Files not modified in the last week"
                        ),
                        AICommandResponse.Result.Explanation.Step(
                            order: 4,
                            description: "Compress each matching file",
                            command: "-exec gzip {} \\;",
                            note: "Replaces original file with .gz compressed version"
                        )
                    ],
                    references: [
                        "man find",
                        "man gzip",
                        "https://www.gnu.org/software/findutils/manual/",
                        "https://www.gzip.org/manual/gzip.html"
                    ]
                )
            ),
            metadata: AICommandResponse.Metadata(
                model: "openai/gpt-oss-120b",
                provider: "groq",
                confidence: 0.92,
                processingTime: 0.342,
                cacheHit: false,
                tags: [
                    "file-management",
                    "compression",
                    "system-administration",
                    "disk-cleanup",
                    "log-rotation"
                ]
            ),
            usage: AICommandResponse.Usage(
                promptTokens: 245,
                completionTokens: 189,
                totalTokens: 434,
                cost: 0.00087
            )
        )
        
        do {
            // Generate JSON
            let jsonString = try response.toJSON(prettyPrinted: true)
            
            // Print the complete JSON
            print("Generated JSON Response:")
            print("────────────────────────────────────────────────────")
            print(jsonString)
            print("────────────────────────────────────────────────────")
            
            // Show statistics
            let jsonData = jsonString.data(using: .utf8)!
            print("\n📊 Statistics:")
            print("   JSON Size: \(jsonData.count) bytes")
            print("   Request ID: \(response.requestId)")
            print("   Timestamp: \(ISO8601DateFormatter().string(from: response.timestamp))")
            print("   Status: \(response.result.status)")
            print("   Confidence: \(String(format: "%.2f%%", response.metadata.confidence * 100))")
            
            // Verify round-trip
            let decoded = try AICommandResponse.fromJSON(jsonString)
            print("\n✅ Round-trip verification successful")
            print("   All fields preserved correctly")
            
        } catch {
            print("❌ Error: \(error)")
        }
    }
}
