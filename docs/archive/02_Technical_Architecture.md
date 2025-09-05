### **文档二：技术架构文档 (Technical Architecture Document)**

**Document Title:** Technical Architecture for AI-Enhanced iOS SSH Client
**Version:** 1.0
**Date:** 2025-09-03
**Author:** Gemini AI Assistant

---

#### **修订历史 (Revision History)**

| Version | Date       | Author                | Changes Description |
| :------ | :--------- | :-------------------- | :------------------ |
| 1.0     | 2025-09-03 | Gemini AI Assistant | Initial draft       |

---

### **1. 架构概述 (Architecture Overview)**

#### **1.1. 设计原则 (Design Principles)**

*   **本地优先 (Local-First)**: 核心功能和用户数据处理优先在设备端完成，以保证最高级别的隐私、安全性和离线可用性。
*   **模块化与分层 (Modularity & Layering)**: 采用清晰的层次结构，将 UI、业务逻辑（Features）和核心服务（Core）解耦，便于维护、测试和扩展。
*   **渐进式增强 (Progressive Enhancement)**: 基础功能不依赖最新系统，同时充分利用新特性（如 iOS 18 Apple Intelligence）为用户提供更优体验。
*   **声明式 UI (Declarative UI)**: 全面拥抱 SwiftUI，利用其数据驱动和声明式特性构建现代化、响应迅速的用户界面。

#### **1.2. 整体架构图 (High-Level Diagram)**

```
┌─────────────────── iOS Client (SSHAIClient) ───────────────────┐
│  ┌──────────────┐ ┌─────────────┐ ┌─────────────┐ │
│  │    SwiftUI   │ │ SwiftTerm   │ │  Core ML    │ │
│  │ (UI Layer)   │ │ (Terminal)  │ │ (Local AI)  │ │
│  └──────┬───────┘ └──────┬──────┘ └──────┬──────┘ │
│         └─────────────── │ ──────────────┘         │
│  ┌───────────────────────┴───────────────────────┐ │
│  │              Features & Core Layer            │ │
│  ├───────────────────────────────────────────────┤ │
│  │ ┌──────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │ │   SwiftNIO   │ │ SQLite.swift│ │ Keychain  │ │
│  │ │   (SSH)      │ │ (Database)  │ │(Security) │ │
│  │ └──────────────┘ └─────────────┘ └───────────┘ │
│  └───────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────┘
                           ▲
                           │ HTTPS API (Fallback Only)
                           ▼
┌─────────────────── Backend Service ────────────────────┐
│          ┌──────────────────────────────────┐          │
│          │       FastAPI (Python)         │          │
│          │ (LLM Inference & Script Sharing) │          │
│          └──────────────────────────────────┘          │
└────────────────────────────────────────────────────────┘
```

#### **1.3. 技术栈选型 (Technology Stack)**

| 领域 (Domain)           | 技术/框架 (Technology/Framework)                         | 理由 (Rationale)                                                                       |
| :---------------------- | :------------------------------------------------------- | :------------------------------------------------------------------------------------- |
| **iOS 客户端**            |                                                          |                                                                                        |
| UI 框架                 | SwiftUI (+ UIKit for SwiftTerm)                          | 苹果官方推荐，现代化的声明式 UI 框架，开发效率高。                                 |
| SSH 连接                | `SwiftNIO SSH`                                           | Apple 官方支持的底层网络框架，性能卓越，安全可靠。                                   |
| 终端模拟                | `SwiftTerm`                                              | 功能成熟、性能优异的开源终端模拟器，支持 xterm 标准。                              |
| 本地数据持久化          | `SQLite.swift`                                           | 轻量级、类型安全的 Swift 封装，性能高，是 iOS 数据持久化的事实标准。               |
| 本地 AI 推理            | `Core ML` & `Apple Intelligence`                         | 充分利用设备端 NPU，实现离线、高隐私的 AI 功能。                                     |
| 安全存储                | `Keychain Services`                                      | 苹果官方提供的最安全机制，用于存储用户凭据和私钥。                                 |
| 异步处理                | `Swift Concurrency (async/await)`                        | 现代化的并发模型，简化异步代码，提高可读性和可维护性。                             |
| **后端服务**            |                                                          |                                                                                        |
| Web 框架                | `FastAPI` (Python)                                       | 性能极高，自带文档，开发效率快，非常适合构建轻量级 API 服务。                      |
| AI 推理                 | `Transformers` / `OpenAI API`                            | 作为本地 AI 的补充和 fallback，提供更强大的模型能力。                              |
| 部署方案                | `Docker`                                                 | 标准化的容器部署方案，简化环境配置和运维，易于扩展。                                 |

---

### **2. 客户端架构 (Client Architecture)**

客户端遵循 MVVM (Model-View-ViewModel) 设计模式，并按照功能领域划分为清晰的层次。

#### **2.1. 目录结构与分层**

*   **`App`**: 应用入口和全局环境配置 (`@main`, SceneDelegate)。
*   **`UI`**: 视图层 (Views)。
    *   **`Theme`**: 定义颜色、字体等全局样式。
    *   **`Components`**: 可复用的 UI 组件（如 AI 建议卡片、风险徽章）。
*   **`Features`**: 业务逻辑层 (ViewModels & Models)。每个功能模块（如终端、连接管理）在此实现其独立的业务逻辑。
*   **`Core`**: 核心服务层，为所有 Feature 提供基础能力。
    *   **`Network`**: 负责网络通信，包括 `SSHConnectionManager` 和 `APIClient`。
    *   **`Data`**: 负责数据持久化，包括 `LocalDataManager` 和数据模型。
    *   **`AI`**: 封装 AI 相关逻辑，如 `HybridIntentClassifier` 和 `CommandGenerator`。
    *   **`Utils`**: 工具类、扩展和常量。
*   **`Resources`**: 资源文件，如 `Assets.xcassets`, `Info.plist`, 和内置脚本。

#### **2.2. 核心组件设计**

*   **`NIOSSHManager`** (实现 `SSHManaging` 协议):
    *   **职责**: 管理所有 SSH 连接的生命周期（连接、认证、执行命令、断开）。
    *   **实现**: 基于 `SwiftNIO SSH`，使用 `async/await` 封装异步操作。通过协议抽象确保可测试性。维护一个 `[UUID: Channel]` 字典来管理多个活动连接。
    *   **架构优势**: 采用依赖注入模式，`TerminalViewModel` 依赖于 `SSHManaging` 协议而非具体实现，便于单元测试和功能扩展。

*   **`HybridIntentClassifier`**:
    *   **职责**: 实现“Auto 模式”的核心意图路由。
    *   **实现**: 采用责任链模式，按序执行分类策略：
        1.  **本地缓存**: 检查输入是否已有分类结果。
        2.  **规则引擎**: 使用正则表达式快速匹配明确的命令格式（`ls`, `cd`, `sudo` 等）。
        3.  **Apple Intelligence (iOS 18+)**: 调用设备端 AI 进行高效、隐私的分类。
        4.  **远程 API Fallback**: 当前三者无法确定时，调用后端 FastAPI 服务进行分类。
        分类结果将被缓存以提高后续性能。

*   **`LocalDataManager`**:
    *   **职责**: 应用所有本地数据的 CRUD (Create, Read, Update, Delete) 管理器。
    *   **实现**: 作为单例或环境对象存在。使用 `SQLite.swift` 定义数据表（如连接、历史记录、脚本、AI 缓存），并提供清晰的异步接口供上层调用。数据库初始化和迁移将在此类中处理。

---

### **3. 后端架构 (Backend Architecture)**

后端服务定位为 **轻量级辅助服务**，而非核心依赖。

*   **服务范围**:
    1.  提供云端大语言模型（LLM）的推理能力，作为设备端 AI 的补充。
    2.  （远期）提供社区脚本的分享和同步功能。
*   **API 设计**:
    *   遵循 RESTful 风格，使用 `FastAPI` 和 `Pydantic` 自动生成交互式 API 文档 (Swagger UI)。
    *   核心端点: `POST /api/v1/generate-command`。
    *   所有请求和响应体均为 JSON 格式，并有严格的类型校验。
*   **部署**:
    *   使用 `Dockerfile` 将 FastAPI 应用打包成一个独立的容器镜像。
    *   通过 `docker-compose.yml` 管理服务的启动和环境变量（如 `OPENAI_API_KEY`），极大简化了本地开发和线上部署的流程。
    *   线上环境建议部署在 Kubernetes 或类似容器编排平台，以实现高可用和弹性伸缩。

---

### **4. 外部集成 (External Integrations)**

*   **Apple Intelligence (iOS 18+)**:
    *   **集成点**: `HybridIntentClassifier`、`CommandGenerator`、`ErrorAnalyzer`。
    *   **策略**: 创建一个 `AppleIntelligenceProvider`，封装对 Apple Intelligence API 的调用。通过 `#available` 检查确保向后兼容性。构建结构化的 Prompt，向模型提供充足的上下文（如操作系统、当前目录、近期命令），以提高生成质量。

*   **Control Center (iOS 18+)**:
    *   **集成点**: `SSHAIClientApp` 入口。
    *   **策略**: 创建 `ControlCenterIntegration` 类，注册一个或多个快捷操作（如"快速连接到最近的服务器"）。利用该入口提升用户访问高频功能的效率。

---

### **5. SSH 实现方案选择 (SSH Implementation Strategy)**

#### **5.1. 方案评估过程**

在项目开发过程中，我们对 SSH 连接的实现方案进行了深入的技术调研和对比：

| 方案 | 优势 | 劣势 | 评估结果 |
|------|------|------|----------|
| **方案 A: SwiftNIO SSH** | • Apple 官方维护<br>• 功能完整，支持 SSHv2<br>• 性能优异<br>• 社区支持活跃<br>• 文档完整 | • API 相对底层<br>• 需要理解 NIO 概念<br>• 初期开发工作量较大 | ✅ **最终选择** |
| **方案 B: swift-ssh-client** | • 高级封装，API 简洁<br>• 开发效率高<br>• 代码量少 | • 第三方维护<br>• 版本管理问题<br>• 依赖解析困难<br>• 文档不完整 | ❌ 放弃 |

#### **5.2. 最终方案：SwiftNIO SSH**

**选择理由：**
1. **稳定性优先**: Apple 官方项目保证长期维护和更新
2. **技术债务最小化**: 避免依赖不稳定的第三方库
3. **学习价值**: 掌握 NIO 对团队技术栈有长期价值
4. **问题解决能力**: 官方库遇到问题更容易找到解决方案

**实现架构：**
- 使用 `ClientBootstrap` 建立 SSH 连接
- 通过 `NIOSSHHandler` 处理 SSH 协议细节
- 实现 `PasswordAuthDelegate` 处理用户认证
- 使用 `ExecHandler` 执行远程命令
- 维护连接池管理多个并发连接

#### **5.3. 协议抽象设计**

为了确保架构的灵活性和可测试性，我们引入了 `SSHManaging` 协议：

```swift
protocol SSHManaging {
    func connect(config: SSHConfig) async throws -> UUID
    func execute(connectionId: UUID, request: CommandRequest) async throws -> CommandResult
    func disconnect(connectionId: UUID) async throws
}
```

**架构优势：**
- **依赖倒置**: `TerminalViewModel` 依赖抽象而非具体实现
- **可测试性**: 轻松创建 Mock 对象进行单元测试
- **可扩展性**: 未来可以轻松切换或添加新的 SSH 实现

---
