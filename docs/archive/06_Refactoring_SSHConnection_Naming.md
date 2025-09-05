# SSHConnection 命名冲突重构方案

**文档版本**: 1.0  
**日期**: 2025-09-05  
**状态**: 待确认

## 1. 问题描述

当前项目中存在两个不同的 `SSHConnection` 结构体定义，导致编译器无法区分：

### UI 层 (ConnectionManager.swift)
```swift
public struct SSHConnection: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var username: String
    public var group: String?           // UI特有
    public var tags: [String]           // UI特有
    public var isFavorite: Bool         // UI特有
    public var lastConnected: Date?     // UI特有
}
```

### 数据层 (LocalDataManager.swift)
```swift
public struct SSHConnection: Equatable, Identifiable {
    public let id: String              // 注意: String vs UUID
    public let name: String
    public let host: String
    public let port: Int
    public let username: String
    public let createdAt: Date         // 数据层特有
}
```

## 2. 解决方案

### 2.1 核心策略
遵循项目架构文档中的分层原则，将两个模型明确区分：
- **UI 层保持 `SSHConnection`**：符合 SwiftUI 视图直接使用的习惯
- **数据层重命名为 `StoredConnection`**：明确表示这是持久化存储的数据模型

### 2.2 具体改动

#### Step 1: 重命名数据层模型
```swift
// LocalDataManager.swift
public struct StoredConnection: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let host: String
    public let port: Int
    public let username: String
    public let createdAt: Date
}
```

#### Step 2: 更新 LocalDataManager 接口
```swift
public final class LocalDataManager {
    public func upsertConnection(_ connection: StoredConnection) throws { }
    public func listConnections() throws -> [StoredConnection] { }
    public func deleteConnection(id: String) throws { }
}
```

#### Step 3: 创建映射扩展
```swift
// 在 LocalDataManager.swift 或单独的文件中
extension StoredConnection {
    /// 从 UI 模型创建存储模型
    init(from uiConnection: SSHConnection) {
        self.id = uiConnection.id.uuidString
        self.name = uiConnection.name
        self.host = uiConnection.host
        self.port = uiConnection.port
        self.username = uiConnection.username
        self.createdAt = Date()
    }
}

extension SSHConnection {
    /// 从存储模型创建 UI 模型（需要提供额外的 UI 特有字段）
    init(from stored: StoredConnection, group: String? = nil, tags: [String] = [], isFavorite: Bool = false, lastConnected: Date? = nil) {
        self.id = UUID(uuidString: stored.id) ?? UUID()
        self.name = stored.name
        self.host = stored.host
        self.port = stored.port
        self.username = stored.username
        self.group = group
        self.tags = tags
        self.isFavorite = isFavorite
        self.lastConnected = lastConnected
    }
}
```

#### Step 4: 更新测试
```swift
// SSHAIClientPersistenceTests.swift
func testConnectionCRUD_withEncryption() throws {
    let connection = StoredConnection(
        id: "1", 
        name: "test-encrypted", 
        host: "localhost.encrypted", 
        port: 2222, 
        username: "testuser-encrypted", 
        createdAt: Date()
    )
    // ... rest of test
}
```

## 3. 影响范围

### 需要修改的文件
1. `Sources/SSHAIClient/Core/Data/LocalDataManager.swift` - 主要改动
2. `Tests/SSHAIClientTests/SSHAIClientPersistenceTests.swift` - 测试更新

### 不受影响的部分
- UI 层代码（ConnectionManager.swift）保持不变
- TerminalViewModel 不直接使用 SSHConnection，无需修改
- 其他功能模块不受影响

## 4. 优势

1. **清晰的关注点分离**：UI 模型和存储模型各司其职
2. **最小化改动**：UI 代码完全不需要修改
3. **扩展性好**：未来可以独立演进两个模型
4. **符合架构原则**：遵循文档中的模块化与分层设计

## 5. 实施步骤

1. 创建此文档并获得确认
2. 在数据层重命名 `SSHConnection` → `StoredConnection`
3. 更新所有相关的方法签名
4. 添加模型转换扩展
5. 更新测试用例
6. 运行测试确保通过
7. 提交 PR

## 6. 未来考虑

- 可以考虑将 UI 特有的字段（group, tags, isFavorite）也持久化
- 可以创建一个专门的 `ConnectionMapper` 服务来处理模型转换
- 考虑使用 Protocol 来定义共享的连接属性

## 7. 决策记录

**为什么不改 UI 层？**
- UI 层的 `SSHConnection` 已经在多个视图中使用
- SwiftUI 开发者习惯直接使用领域模型名称
- UI 层的模型包含更多展示相关的属性

**为什么选择 `StoredConnection` 这个名字？**
- 明确表示这是持久化存储的版本
- 避免与 UI 层混淆
- 符合数据层的职责定位
