# iOS 架构最佳实践审查报告

**文档版本**: 1.0  
**日期**: 2025-09-05  
**审查范围**: SSHConnection 命名冲突解决方案

## 1. iOS/SwiftUI 架构最佳实践对照

### ✅ 符合的最佳实践

#### 1.1 MVVM 架构模式
```
✓ Model (数据层): StoredConnection - 纯数据结构
✓ View (UI层): ConnectionManager - SwiftUI视图
✓ ViewModel: ConnectionManagerViewModel - 业务逻辑
```

#### 1.2 单一职责原则 (SRP)
- **UI Model** (`SSHConnection`): 专注于展示需求
- **Storage Model** (`StoredConnection`): 专注于持久化
- 每个模型只负责自己的领域

#### 1.3 依赖倒置原则 (DIP)
- ViewModel 不直接依赖具体的存储实现
- 使用协议抽象 (SSHManaging)

### ⚠️ 需要改进的地方

#### 1.4 数据流向问题
当前方案缺少清晰的数据流定义：

```swift
// 🔴 问题：直接在扩展中转换模型
extension StoredConnection {
    init(from uiConnection: SSHConnection) { }
}

// 🟢 更好的做法：使用独立的 Repository 模式
protocol ConnectionRepository {
    func save(_ connection: SSHConnection) async throws
    func loadAll() async throws -> [SSHConnection]
}
```

## 2. Apple 官方推荐的做法

### 2.1 Core Data 模式参考
Apple 在 Core Data 中使用类似的分离：
- **NSManagedObject** (存储层)
- **Domain Model** (业务层)
- **View Model** (展示层)

### 2.2 SwiftData (iOS 17+) 模式
```swift
// Apple 推荐的新模式
@Model  // 持久化模型
class StoredConnection {
    var id: String
    var name: String
    // ...
}

@Observable  // UI 模型
class ConnectionViewModel {
    var connections: [UIConnection] = []
}
```

## 3. 业界最佳实践对比

### 3.1 Spotify iOS App 架构
```
Feature/
├── Models/
│   ├── DomainModels/    (业务模型)
│   └── DTOs/             (数据传输对象)
├── ViewModels/
├── Views/
└── Services/
```

### 3.2 Airbnb iOS 架构
- 使用独立的 **Data Transfer Objects (DTO)**
- UI 模型和存储模型完全分离
- 通过 **Mapper** 层转换

## 4. 改进后的推荐方案

### 4.1 三层模型架构

```swift
// 1️⃣ Domain Model (领域模型) - 业务核心
struct Connection {
    let id: UUID
    let name: String
    let host: String
    let port: Int
    let username: String
    // 业务逻辑相关
}

// 2️⃣ UI Model (展示模型) - UI专用
struct ConnectionUIModel: Identifiable {
    let id: UUID
    var name: String
    var displayName: String  // UI专用计算属性
    var statusColor: Color   // UI专用
    var group: String?
    var tags: [String]
    var isFavorite: Bool
}

// 3️⃣ Storage Model (存储模型) - 持久化专用
struct ConnectionEntity {
    let id: String
    let name: String
    let encryptedHost: String    // 加密存储
    let encryptedUsername: String
    let port: Int
    let createdAt: Date
}
```

### 4.2 使用 Repository 模式

```swift
// Repository 协议
protocol ConnectionRepositoryProtocol {
    func fetchAll() async throws -> [Connection]
    func save(_ connection: Connection) async throws
    func delete(id: UUID) async throws
}

// 具体实现
final class ConnectionRepository: ConnectionRepositoryProtocol {
    private let dataManager: LocalDataManager
    private let mapper: ConnectionMapper
    
    func fetchAll() async throws -> [Connection] {
        let entities = try await dataManager.fetchConnectionEntities()
        return entities.map(mapper.toDomain)
    }
}

// Mapper 负责转换
final class ConnectionMapper {
    func toDomain(_ entity: ConnectionEntity) -> Connection { }
    func toEntity(_ domain: Connection) -> ConnectionEntity { }
    func toUI(_ domain: Connection) -> ConnectionUIModel { }
}
```

### 4.3 ViewModel 使用 Repository

```swift
@MainActor
final class ConnectionManagerViewModel: ObservableObject {
    @Published var uiModels: [ConnectionUIModel] = []
    
    private let repository: ConnectionRepositoryProtocol
    private let mapper: ConnectionMapper
    
    func loadConnections() async {
        do {
            let connections = try await repository.fetchAll()
            self.uiModels = connections.map(mapper.toUI)
        } catch {
            // Handle error
        }
    }
}
```

## 5. 命名规范建议

### iOS 社区常见命名约定

| 层级 | 常见命名模式 | 示例 |
|------|------------|------|
| UI Model | `[Name]` 或 `[Name]ViewModel` | `Connection`, `ConnectionViewModel` |
| Domain Model | `[Name]` 或 `[Name]Model` | `Connection`, `ConnectionModel` |
| Storage Model | `[Name]Entity` 或 `[Name]DTO` | `ConnectionEntity`, `ConnectionDTO` |
| Core Data | `[Name]ManagedObject` | `ConnectionManagedObject` |

### 推荐命名方案

```swift
// ✅ 推荐 - 清晰的三层命名
ConnectionUIModel     // UI层
Connection           // 领域层
ConnectionEntity     // 存储层

// ⚠️ 当前方案
SSHConnection        // UI层 (模糊)
StoredConnection     // 存储层 (可接受)
```

## 6. 最终建议

### 6.1 短期方案（快速修复）
保持当前的重命名方案，但需要补充：
1. ✅ `StoredConnection` 重命名可以接受
2. ➕ 添加 `ConnectionRepository` 抽象层
3. ➕ 创建独立的 `ConnectionMapper` 类
4. ➕ 避免直接在模型扩展中做转换

### 6.2 长期方案（架构优化）
```
Features/
├── Connection/
│   ├── Models/
│   │   ├── Connection.swift           (领域模型)
│   │   ├── ConnectionUIModel.swift    (UI模型)
│   │   └── ConnectionEntity.swift     (存储模型)
│   ├── ViewModels/
│   │   └── ConnectionViewModel.swift
│   ├── Views/
│   │   └── ConnectionView.swift
│   ├── Repository/
│   │   └── ConnectionRepository.swift
│   └── Mappers/
│       └── ConnectionMapper.swift
```

## 7. 决策矩阵

| 方案 | 实现复杂度 | 可维护性 | 符合最佳实践 | 推荐度 |
|------|-----------|---------|--------------|--------|
| 当前方案 (SSHConnection + StoredConnection) | 低 | 中 | 70% | ⭐⭐⭐ |
| 加入 Repository 模式 | 中 | 高 | 85% | ⭐⭐⭐⭐ |
| 完整三层架构 | 高 | 很高 | 95% | ⭐⭐⭐⭐⭐ |

## 8. 行动建议

### 立即执行（Phase 1）
1. ✅ 执行 `StoredConnection` 重命名
2. ✅ 创建 `ConnectionRepository` 协议和实现
3. ✅ 将模型转换逻辑移到独立的 Mapper

### 近期优化（Phase 2）
1. 引入领域模型 `Connection` 作为中间层
2. 重构 ViewModel 使用 Repository
3. 添加单元测试覆盖 Mapper 逻辑

### 长期规划（Phase 3）
1. 迁移到 SwiftData（iOS 17+）
2. 实现完整的 Clean Architecture
3. 引入 Combine/AsyncStream 实现响应式数据流

## 9. 风险评估

### 当前方案的风险
- 🟡 **低风险**: 模型转换逻辑分散在扩展中
- 🟡 **低风险**: 缺少中间领域模型
- 🟢 **无风险**: 基本满足功能需求

### 建议缓解措施
1. 逐步重构，不要一次性大改
2. 先添加测试覆盖
3. 保持向后兼容

## 10. 结论

**当前方案评分: 7/10**

✅ **优点**：
- 解决了命名冲突
- 最小化改动
- 基本符合 MVVM

⚠️ **改进空间**：
- 缺少 Repository 抽象
- 模型转换逻辑位置不当
- 没有独立的领域模型

**最终建议**：
1. **短期**: 接受当前方案，快速解决构建问题
2. **中期**: 引入 Repository 和 Mapper 模式
3. **长期**: 迁移到完整的 Clean Architecture

---

## 附录：参考资源

1. [Apple: Model-View-ViewModel in SwiftUI](https://developer.apple.com/documentation/swiftui)
2. [Ray Wenderlich: iOS Architecture Patterns](https://www.raywenderlich.com/books/design-patterns-by-tutorials)
3. [Point-Free: Modern SwiftUI Architecture](https://www.pointfree.co)
4. [Airbnb iOS Architecture](https://github.com/airbnb/swift-style-guide)
5. [Clean Architecture for SwiftUI](https://nalexn.github.io/clean-architecture-swiftui/)
