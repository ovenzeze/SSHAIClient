# 🚀 立即可执行的开发任务

## 今天可以开始的任务（无依赖）

### 选项 A: SSH 核心功能
```bash
# 开始实现真正的 SSH 连接
open Sources/SSHAIClient/Core/Network/NIOSSHManager.swift
```
**首要任务**: 实现 `connect()` 方法
**参考**: [SwiftNIO SSH Examples](https://github.com/apple/swift-nio-ssh/tree/main/Sources/NIOSSHClient)

### 选项 B: AI 命令生成增强
```bash
# 扩展命令规则库
open Sources/SSHAIClient/Core/AI/CommandGenerator.swift
```
**首要任务**: 添加更多命令模式
**立即可加**: git, docker, kubectl, systemctl 等常用命令

### 选项 C: 数据持久化
```bash
# 实现数据存储
open Sources/SSHAIClient/Core/Data/LocalDataManager.swift
```
**首要任务**: 创建数据库表结构和基本 CRUD
**工具**: SQLite.swift 已经在依赖中

### 选项 D: UI 连接管理器
```bash
# 创建连接管理界面
touch Sources/SSHAIClient/UI/Views/ConnectionManager.swift
```
**首要任务**: 创建服务器列表界面
**设计**: 类似 Termius/Prompt 的连接管理

---

## 快速任务（1小时内可完成）

### 1. 扩展命令规则（最简单）
在 `CommandGenerator.swift` 中添加：
```swift
// Git 命令
if lowercaseQuery.contains("git") && lowercaseQuery.contains("status") {
    return CommandSuggestion(
        command: "git status",
        explanation: "显示工作目录状态",
        risk: .safe,
        confidence: 0.9
    )
}

// Docker 命令
if lowercaseQuery.contains("docker") && lowercaseQuery.contains("ps") {
    return CommandSuggestion(
        command: "docker ps -a",
        explanation: "列出所有容器",
        risk: .safe,
        confidence: 0.85
    )
}
```

### 2. 添加连接历史存储
在 `LocalDataManager.swift` 中实现：
```swift
func saveConnection(_ config: SSHConfig) async throws {
    // 使用 UserDefaults 快速实现
    var history = UserDefaults.standard.array(forKey: "ssh_history") as? [[String: Any]] ?? []
    history.append([
        "host": config.host,
        "username": config.username,
        "timestamp": Date().timeIntervalSince1970
    ])
    UserDefaults.standard.set(history, forKey: "ssh_history")
}
```

### 3. 创建设置界面骨架
创建 `SettingsView.swift`:
```swift
struct SettingsView: View {
    @AppStorage("theme") var theme = "auto"
    @AppStorage("ai_enabled") var aiEnabled = true
    
    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: $theme) {
                    Text("自动").tag("auto")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
            }
            Section("AI 功能") {
                Toggle("启用 AI 建议", isOn: $aiEnabled)
            }
        }
    }
}
```

---

## 本周目标

### 周一-周二
- [ ] 选择一个 Track 深入
- [ ] 完成该 Track 的基础功能
- [ ] 编写单元测试

### 周三-周四
- [ ] 集成到主应用
- [ ] 修复发现的问题
- [ ] 性能优化

### 周五
- [ ] 代码审查
- [ ] 文档更新
- [ ] 准备下周计划

---

## 测试命令

```bash
# 运行测试
swift test

# 构建调试版本
swift build

# 运行应用
./.build/debug/SSHAIClientApp

# 创建应用包
./Scripts/build-app.sh
```

---

## 需要帮助？

- **SSH 实现问题**: 查看 SwiftNIO SSH 示例代码
- **AI 集成**: 先用规则，后期接入真正的 AI
- **数据库设计**: 参考 `Documentation/05_Parallel_Development_Plan.md`
- **UI 设计**: 参考 `Documentation/03_UI_UX_Design.md`

---

## 🎯 推荐起点

如果不确定从哪开始，建议：
1. **先扩展 CommandGenerator** - 最简单，立即见效
2. **再实现基础数据存储** - 为后续功能打基础
3. **然后处理 SSH 连接** - 核心功能，但较复杂
4. **最后完善 UI** - 基于前面的功能构建

记住：**小步快跑，频繁提交！**
