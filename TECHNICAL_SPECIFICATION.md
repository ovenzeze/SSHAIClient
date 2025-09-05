# SSHAIClient 技术规范与编码标准

**版本**: 1.0  
**生效日期**: 2025-09-05  
**状态**: 强制执行

> ⚠️ **重要**: 所有代码提交前必须通过此文档的检查清单

---

## 1. 架构原则

### 1.1 核心原则 (SOLID)

#### S - 单一职责原则 (Single Responsibility)
```swift
// ❌ 错误：一个类负责太多事情
class ConnectionManager {
    func connect() { }
    func saveToDatabase() { }
    func encryptData() { }
    func updateUI() { }
}

// ✅ 正确：职责分离
class ConnectionService { func connect() { } }
class ConnectionRepository { func save() { } }
class EncryptionService { func encrypt() { } }
class ConnectionViewModel { func updateUI() { } }
```

#### O - 开闭原则 (Open-Closed)
```swift
// ✅ 对扩展开放，对修改关闭
protocol SSHManaging {
    func connect(config: SSHConfig) async throws -> UUID
}

// 可以添加新实现而不修改现有代码
class NIOSSHManager: SSHManaging { }
class MockSSHManager: SSHManaging { }
```

#### L - 里氏替换原则 (Liskov Substitution)
子类必须能够替换父类而不破坏程序功能

#### I - 接口隔离原则 (Interface Segregation)
```swift
// ❌ 错误：臃肿的协议
protocol DataManager {
    func saveConnection()
    func saveScript()
    func saveHistory()
    func encrypt()
    func decrypt()
}

// ✅ 正确：细粒度协议
protocol ConnectionPersisting {
    func save(_ connection: StoredConnection) throws
}

protocol Encrypting {
    func encrypt(_ data: Data) throws -> Data
}
```

#### D - 依赖倒置原则 (Dependency Inversion)
```swift
// ✅ 依赖抽象而非具体实现
class TerminalViewModel {
    private let ssh: SSHManaging  // 协议，不是具体类
    private let repository: ConnectionRepositoryProtocol  // 协议
    
    init(ssh: SSHManaging, repository: ConnectionRepositoryProtocol) {
        self.ssh = ssh
        self.repository = repository
    }
}
```

### 1.2 分层架构

```
┌─────────────────────────────────────────┐
│            Presentation Layer           │
│         (Views & ViewModels)             │
├─────────────────────────────────────────┤
│            Business Layer               │
│      (Services & Use Cases)             │
├─────────────────────────────────────────┤
│              Data Layer                 │
│    (Repositories & Data Sources)        │
└─────────────────────────────────────────┘
```

**层级规则**:
- ✅ 上层可以依赖下层
- ❌ 下层不能依赖上层
- ❌ 跨层直接依赖

---

## 2. 命名规范

### 2.1 模型命名

| 层级 | 命名模式 | 示例 | 用途 |
|------|---------|------|------|
| **UI 模型** | `[Feature]` | `SSHConnection` | SwiftUI 视图直接使用 |
| **领域模型** | `[Feature]Model` | `ConnectionModel` | 业务逻辑核心 |
| **存储模型** | `Stored[Feature]` | `StoredConnection` | 数据库持久化 |
| **DTO** | `[Feature]DTO` | `ConnectionDTO` | 网络传输 |
| **实体** | `[Feature]Entity` | `ConnectionEntity` | Core Data/SwiftData |

### 2.2 文件组织

```
Features/
├── [FeatureName]/
│   ├── Models/
│   │   ├── [Feature].swift           // UI 模型
│   │   ├── [Feature]Model.swift      // 领域模型
│   │   └── Stored[Feature].swift     // 存储模型
│   ├── ViewModels/
│   │   └── [Feature]ViewModel.swift
│   ├── Views/
│   │   └── [Feature]View.swift
│   ├── Services/
│   │   └── [Feature]Service.swift
│   └── Repositories/
│       └── [Feature]Repository.swift
```

### 2.3 命名约定

```swift
// 类和结构体：PascalCase
class ConnectionManager { }
struct SSHConfig { }

// 协议：PascalCase + 形容词/动词ing 或 Protocol 后缀
protocol SSHManaging { }
protocol ConnectionRepositoryProtocol { }

// 函数和变量：camelCase
func connectToServer() { }
var isConnected: Bool

// 常量：根据作用域
private let maxRetries = 3  // 局部常量
static let defaultPort = 22  // 类型常量

// 私有成员：无下划线前缀
private var connection: SSHConnection  // ✅
private var _connection: SSHConnection  // ❌
```

---

## 3. 数据流规范

### 3.1 单向数据流

```
User Input → View → ViewModel → Service → Repository → Database
                ↑                                          ↓
                └──────────── State Updates ←─────────────┘
```

### 3.2 状态管理

```swift
// ViewModel 是状态的唯一真实来源
@MainActor
final class ConnectionViewModel: ObservableObject {
    // ✅ 只读的 Published 属性
    @Published private(set) var connections: [SSHConnection] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: Error?
    
    // ✅ 通过方法修改状态
    func loadConnections() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            connections = try await repository.fetchAll()
            error = nil
        } catch {
            self.error = error
        }
    }
}
```

### 3.3 Repository 模式

```swift
// ✅ 正确的 Repository 实现
protocol ConnectionRepositoryProtocol {
    func fetchAll() async throws -> [Connection]
    func save(_ connection: Connection) async throws
    func delete(id: UUID) async throws
}

final class ConnectionRepository: ConnectionRepositoryProtocol {
    private let localDataSource: LocalDataSource
    private let remoteDataSource: RemoteDataSource?
    private let mapper: ConnectionMapper
    
    // Repository 负责协调多个数据源
    func fetchAll() async throws -> [Connection] {
        // 先尝试本地
        if let local = try? await localDataSource.fetchAll() {
            return local.map(mapper.toDomain)
        }
        
        // 失败则尝试远程
        if let remote = remoteDataSource {
            let connections = try await remote.fetchAll()
            try await localDataSource.save(connections)
            return connections.map(mapper.toDomain)
        }
        
        return []
    }
}
```

---

## 4. 异步编程规范

### 4.1 使用 async/await

```swift
// ✅ 正确：使用 async/await
func fetchData() async throws -> Data {
    return try await URLSession.shared.data(from: url).0
}

// ❌ 错误：避免回调地狱
func fetchData(completion: @escaping (Result<Data, Error>) -> Void) {
    // 避免使用
}
```

### 4.2 MainActor 使用

```swift
// ✅ ViewModel 使用 @MainActor
@MainActor
final class ViewModel: ObservableObject {
    @Published var data: [Item] = []
    
    // 自动在主线程更新 UI
    func updateData() async {
        data = await fetchItems()
    }
}

// ✅ 非 UI 代码不使用 @MainActor
final class DataService {  // 没有 @MainActor
    func fetchData() async throws -> Data {
        // 可以在后台线程运行
    }
}
```

### 4.3 错误处理

```swift
// ✅ 明确的错误类型
enum ConnectionError: LocalizedError {
    case invalidHost
    case authenticationFailed
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidHost: return "Invalid host address"
        case .authenticationFailed: return "Authentication failed"
        case .timeout: return "Connection timeout"
        }
    }
}

// ✅ 正确的错误传播
func connect() async throws {
    do {
        try await performConnection()
    } catch {
        // 记录错误
        logger.error("Connection failed: \(error)")
        // 重新抛出以供上层处理
        throw error
    }
}
```

---

## 5. 安全规范

### 5.1 敏感数据处理

```swift
// ✅ 使用 Keychain 存储敏感信息
class SecureStore {
    static func savePassword(_ password: String, for account: String) throws {
        // 使用 Keychain Services
    }
}

// ❌ 错误：不要硬编码敏感信息
let apiKey = "sk-1234567890"  // 永远不要这样做！

// ✅ 正确：从安全存储读取
let apiKey = try SecureStore.getAPIKey()
```

### 5.2 加密规范

```swift
// ✅ 所有存储的敏感数据必须加密
struct StoredConnection {
    let encryptedHost: String  // 加密存储
    let encryptedUsername: String  // 加密存储
    let port: Int  // 非敏感，可明文
}

// ✅ 使用 CryptoKit 进行加密
import CryptoKit

func encrypt(_ plaintext: String) throws -> String {
    let key = try SecureStore.getEncryptionKey()
    let sealed = try AES.GCM.seal(Data(plaintext.utf8), using: key)
    return sealed.combined!.base64EncodedString()
}
```

---

## 6. 测试规范

### 6.1 测试覆盖要求

- **最低覆盖率**: 70%
- **关键路径覆盖**: 100%
- **新代码覆盖**: 80%

### 6.2 测试结构

```swift
// ✅ AAA 模式：Arrange-Act-Assert
func testConnectionSave() async throws {
    // Arrange
    let connection = createTestConnection()
    let repository = ConnectionRepository(dataSource: mockDataSource)
    
    // Act
    try await repository.save(connection)
    
    // Assert
    let saved = try await repository.fetchAll()
    XCTAssertEqual(saved.count, 1)
    XCTAssertEqual(saved.first?.id, connection.id)
}

// ✅ 使用 Mock 进行隔离测试
class MockSSHManager: SSHManaging {
    var connectCalled = false
    var connectResult: Result<UUID, Error> = .success(UUID())
    
    func connect(config: SSHConfig) async throws -> UUID {
        connectCalled = true
        return try connectResult.get()
    }
}
```

### 6.3 测试命名

```swift
// 格式：test_被测方法_测试场景_预期结果
func test_connect_withValidCredentials_shouldReturnConnectionId() { }
func test_save_whenDatabaseFull_shouldThrowError() { }
```

---

## 7. 性能规范

### 7.1 内存管理

```swift
// ✅ 避免循环引用
class ViewModel {
    var onUpdate: (() -> Void)?
    
    func setupBindings() {
        // 使用 [weak self] 或 [unowned self]
        service.observe { [weak self] data in
            self?.process(data)
        }
    }
}

// ✅ 及时释放大对象
func processLargeFile() async {
    autoreleasepool {
        let data = loadLargeData()
        process(data)
    }  // data 在这里释放
}
```

### 7.2 并发控制

```swift
// ✅ 使用 Actor 保证线程安全
actor ConnectionCache {
    private var cache: [UUID: SSHConnection] = [:]
    
    func get(_ id: UUID) -> SSHConnection? {
        cache[id]
    }
    
    func set(_ connection: SSHConnection) {
        cache[connection.id] = connection
    }
}

// ✅ 避免主线程阻塞
@MainActor
func updateUI() async {
    // 重计算移到后台
    let result = await Task.detached {
        return performHeavyCalculation()
    }.value
    
    // 只在主线程更新 UI
    displayResult(result)
}
```

---

## 8. 代码审查清单

### 提交前必须检查

#### 架构 ✓
- [ ] 遵循 SOLID 原则
- [ ] 没有跨层直接依赖
- [ ] 使用依赖注入
- [ ] Repository 模式正确实现

#### 命名 ✓
- [ ] 模型命名符合规范
- [ ] 文件组织结构正确
- [ ] 变量和函数命名清晰

#### 数据流 ✓
- [ ] 单向数据流
- [ ] ViewModel 是唯一状态源
- [ ] 正确使用 @Published

#### 异步 ✓
- [ ] 使用 async/await
- [ ] 正确使用 @MainActor
- [ ] 错误处理完整

#### 安全 ✓
- [ ] 敏感数据已加密
- [ ] 使用 Keychain 存储密码
- [ ] 没有硬编码的密钥

#### 测试 ✓
- [ ] 新代码有测试覆盖
- [ ] 测试使用 AAA 模式
- [ ] 使用 Mock 隔离依赖

#### 性能 ✓
- [ ] 没有内存泄漏风险
- [ ] 大对象及时释放
- [ ] 不阻塞主线程

#### 文档 ✓
- [ ] 复杂逻辑有注释
- [ ] 公共 API 有文档
- [ ] README 已更新

---

## 9. Git 提交规范

### 9.1 提交消息格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 9.2 Type 类型

- `feat`: 新功能
- `fix`: 修复 bug
- `refactor`: 重构（不影响功能）
- `perf`: 性能优化
- `test`: 测试相关
- `docs`: 文档更新
- `style`: 代码格式（不影响逻辑）
- `chore`: 构建或辅助工具变动

### 9.3 示例

```bash
feat(connection): add Repository pattern for data persistence

- Implement ConnectionRepository protocol
- Add ConnectionMapper for model transformation
- Update ViewModel to use Repository
- Add unit tests for Repository

BREAKING CHANGE: SSHConnection renamed to StoredConnection in data layer
```

---

## 10. 禁止事项 🚫

### 绝对禁止

1. **硬编码敏感信息**
   ```swift
   // ❌ 绝对禁止
   let password = "admin123"
   let apiKey = "sk-xxxxx"
   ```

2. **跳过错误处理**
   ```swift
   // ❌ 绝对禁止
   try! dangerousOperation()
   _ = try? saveData()  // 忽略错误
   ```

3. **强制解包**
   ```swift
   // ❌ 绝对禁止
   let value = optional!
   ```

4. **同步阻塞主线程**
   ```swift
   // ❌ 绝对禁止
   Thread.sleep(forTimeInterval: 5)
   DispatchQueue.main.sync { }
   ```

5. **跨层直接访问**
   ```swift
   // ❌ 绝对禁止
   class MyView: View {
       let database = SQLiteDatabase()  // View 直接访问数据库
   }
   ```

---

## 11. 渐进式改进策略

### Phase 1: 基础合规 (必须)
- ✅ SOLID 原则
- ✅ 基本命名规范
- ✅ 错误处理

### Phase 2: 架构优化 (推荐)
- ➕ Repository 模式
- ➕ 依赖注入
- ➕ 单元测试

### Phase 3: 卓越工程 (目标)
- ⭐ 90% 测试覆盖
- ⭐ 完整的 CI/CD
- ⭐ 性能监控

---

## 12. 参考资源

### 官方文档
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SwiftUI Best Practices](https://developer.apple.com/documentation/swiftui)

### 推荐阅读
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [SOLID Principles](https://www.digitalocean.com/community/conceptual-articles/s-o-l-i-d-the-first-five-principles-of-object-oriented-design)
- [iOS Good Practices](https://github.com/futurice/ios-good-practices)

---

## 版本历史

| 版本 | 日期 | 作者 | 变更说明 |
|------|------|------|----------|
| 1.0 | 2025-09-05 | AI Assistant | 初始版本，建立基础规范 |

---

**⚠️ 此文档为强制性规范，所有团队成员必须遵守**

**最后更新**: 2025-09-05
