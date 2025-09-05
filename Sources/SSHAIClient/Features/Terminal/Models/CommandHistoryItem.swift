import Foundation

/// 命令历史记录项，包含命令和其执行结果
public struct CommandHistoryItem: Identifiable {
    public let id = UUID()
    public let command: String
    public let output: String
    public let error: String?
    public let exitCode: Int32
    public let timestamp: Date
    
    public init(
        command: String,
        output: String,
        error: String?,
        exitCode: Int32,
        timestamp: Date
    ) {
        self.command = command
        self.output = output
        self.error = error
        self.exitCode = exitCode
        self.timestamp = timestamp
    }
    
    /// 是否执行成功
    public var isSuccess: Bool {
        return exitCode == 0
    }
    
    /// 格式化的时间戳
    public var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
}
