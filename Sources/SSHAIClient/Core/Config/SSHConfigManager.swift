import Foundation
import Security

/// 管理SSH连接配置的单例类，使用UserDefaults存储
@available(macOS 11.0, *)
@MainActor
public class SSHConfigManager: ObservableObject {
    public static let shared = SSHConfigManager()
    
    // 使用@Published使SwiftUI视图能响应变化
    @Published public var host: String {
        didSet { UserDefaults.standard.set(host, forKey: Keys.host) }
    }
    
    @Published public var port: Int {
        didSet { UserDefaults.standard.set(port, forKey: Keys.port) }
    }
    
    @Published public var username: String {
        didSet { UserDefaults.standard.set(username, forKey: Keys.username) }
    }
    
    @Published public var authMethod: AuthMethod {
        didSet { 
            UserDefaults.standard.set(authMethod.rawValue, forKey: Keys.authMethod)
            saveAuthDetails()
        }
    }
    
    @Published public var password: String = "" {
        didSet { 
            if authMethod == .password {
                saveToKeychain(password, forAccount: KeychainKeys.passwordAccount)
            }
        }
    }
    
    @Published public var privateKeyPath: String = "" {
        didSet {
            if authMethod == .privateKey {
                UserDefaults.standard.set(privateKeyPath, forKey: Keys.privateKeyPath)
            }
        }
    }
    
    @Published public var passphrase: String = "" {
        didSet {
            if authMethod == .privateKey && !passphrase.isEmpty {
                saveToKeychain(passphrase, forAccount: KeychainKeys.passphraseAccount)
            }
        }
    }
    
    @Published public var autoConnect: Bool {
        didSet { UserDefaults.standard.set(autoConnect, forKey: Keys.autoConnect) }
    }
    
    @Published public var connectionTimeout: Int {
        didSet { UserDefaults.standard.set(connectionTimeout, forKey: Keys.timeout) }
    }
    
    // 记住最近使用的连接
    @Published public var recentHosts: [String] = [] {
        didSet { UserDefaults.standard.set(recentHosts, forKey: Keys.recentHosts) }
    }
    
    public enum AuthMethod: String, CaseIterable {
        case password = "password"
        case privateKey = "privateKey"
        case none = "none"  // 对于本地测试或无需认证的场景
        
        public var displayName: String {
            switch self {
            case .password: return "Password"
            case .privateKey: return "SSH Key"
            case .none: return "None"
            }
        }
    }
    
    private struct Keys {
        static let host = "ssh.host"
        static let port = "ssh.port"
        static let username = "ssh.username"
        static let authMethod = "ssh.authMethod"
        static let privateKeyPath = "ssh.privateKeyPath"
        static let autoConnect = "ssh.autoConnect"
        static let timeout = "ssh.timeout"
        static let recentHosts = "ssh.recentHosts"
    }
    
    private struct KeychainKeys {
        static let service = "com.sshai.client"
        static let passwordAccount = "password"
        static let passphraseAccount = "passphrase"
    }
    
    private init() {
        // 加载存储的值，如果没有则使用智能默认值
        self.host = UserDefaults.standard.string(forKey: Keys.host) ?? "localhost"
        self.port = UserDefaults.standard.object(forKey: Keys.port) as? Int ?? 22
        
        // 默认使用当前系统用户名
        self.username = UserDefaults.standard.string(forKey: Keys.username) ?? NSUserName()
        
        let authMethodRaw = UserDefaults.standard.string(forKey: Keys.authMethod) ?? AuthMethod.password.rawValue
        self.authMethod = AuthMethod(rawValue: authMethodRaw) ?? .password
        
        self.privateKeyPath = UserDefaults.standard.string(forKey: Keys.privateKeyPath) ?? "~/.ssh/id_rsa"
        self.autoConnect = UserDefaults.standard.bool(forKey: Keys.autoConnect)
        self.connectionTimeout = UserDefaults.standard.object(forKey: Keys.timeout) as? Int ?? 10
        self.recentHosts = UserDefaults.standard.stringArray(forKey: Keys.recentHosts) ?? ["localhost", "127.0.0.1"]
        
        // 从Keychain加载敏感信息（系统Keychain）
        self.password = Keychain.load(service: KeychainKeys.service, account: KeychainKeys.passwordAccount) ?? ""
        self.passphrase = Keychain.load(service: KeychainKeys.service, account: KeychainKeys.passphraseAccount) ?? ""
    }
    
    /// 生成当前配置的SSHConfig对象
    public func currentConfig() -> SSHConfig {
        let authentication: SSHConfig.Authentication
        
        switch authMethod {
        case .password:
            authentication = .password(password)
        case .privateKey:
            // 扩展home路径
            let expandedPath = NSString(string: privateKeyPath).expandingTildeInPath
            // 读取私钥文件内容
            do {
                let keyData = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
                authentication = .privateKey(pem: keyData, passphrase: passphrase.isEmpty ? nil : passphrase)
            } catch {
                print("Error reading private key file at \(expandedPath): \(error)")
                // 生成一定会失败的配置，避免误导性回退
                authentication = .privateKey(pem: Data(), passphrase: nil)
            }
        case .none:
            // 对于无认证场景，使用空密码
            authentication = .password("")
        }
        
        return SSHConfig(
            host: host,
            port: port,
            username: username,
            authentication: authentication,
            timeoutSeconds: TimeInterval(connectionTimeout)
        )
    }
    
    /// 添加主机到最近使用列表
    public func addToRecentHosts(_ host: String) {
        if !recentHosts.contains(host) {
            recentHosts.insert(host, at: 0)
            if recentHosts.count > 10 { // 只保留最近10个
                recentHosts = Array(recentHosts.prefix(10))
            }
        }
    }
    
    /// 重置为默认配置
    public func resetToDefaults() {
        host = "localhost"
        port = 22
        username = NSUserName()
        authMethod = .password
        password = ""
        privateKeyPath = "~/.ssh/id_rsa"
        passphrase = ""
        autoConnect = false
        connectionTimeout = 10
    }
    
    /// 验证配置是否完整有效
    public func isConfigValid() -> (valid: Bool, message: String?) {
        // 基础验证
        if host.isEmpty {
            return (false, "Host cannot be empty")
        }
        
        if port < 1 || port > 65535 {
            return (false, "Port must be between 1 and 65535")
        }
        
        if username.isEmpty {
            return (false, "Username cannot be empty")
        }
        
        // 根据认证方式验证
        switch authMethod {
        case .password:
            // 统一策略：不允许空密码，避免混淆
            if password.isEmpty {
                return (false, "Password cannot be empty")
            }
            return (true, nil)
        case .privateKey:
            let expandedPath = NSString(string: privateKeyPath).expandingTildeInPath
            if !FileManager.default.fileExists(atPath: expandedPath) {
                return (false, "Private key file not found at: \(privateKeyPath)")
            }
            return (true, nil)
        case .none:
            // 通常只用于本地或测试
            if host != "localhost" && host != "127.0.0.1" {
                return (false, "No authentication is only supported for localhost")
            }
            return (true, nil)
        }
    }
    
    // MARK: - Private Helpers
    
    private func saveAuthDetails() {
        // 清理不相关的认证信息
        switch authMethod {
        case .password:
            UserDefaults.standard.removeObject(forKey: Keys.privateKeyPath)
            deleteFromKeychain(forAccount: KeychainKeys.passphraseAccount)
        case .privateKey:
            deleteFromKeychain(forAccount: KeychainKeys.passwordAccount)
        case .none:
            deleteFromKeychain(forAccount: KeychainKeys.passwordAccount)
            deleteFromKeychain(forAccount: KeychainKeys.passphraseAccount)
        }
    }
    
    // MARK: - Keychain Helpers (system keychain)
    
    private func saveToKeychain(_ value: String, forAccount account: String) {
        Keychain.save(service: KeychainKeys.service, account: account, value: value)
    }
    
    private func deleteFromKeychain(forAccount account: String) {
        Keychain.delete(service: KeychainKeys.service, account: account)
    }
}
