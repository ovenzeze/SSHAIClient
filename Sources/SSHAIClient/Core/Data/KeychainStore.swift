import Foundation
import Security
import CryptoKit

enum KeychainStore {
    private static let account = "com.sshaiclient.datakey.v1"

    static func getOrCreateKey() throws -> SymmetricKey {
        if let existing = try? loadKeyData() {
            return SymmetricKey(data: existing)
        }
        // Generate random 32-byte key
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { throw NSError(domain: "KeychainStore", code: Int(status)) }
        let data = Data(bytes)
        try saveKeyData(data)
        return SymmetricKey(data: data)
    }

    private static func loadKeyData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw NSError(domain: "KeychainStore", code: Int(status))
        }
        return data
    }

    private static func saveKeyData(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            // Update existing
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: account
            ]
            let attrs: [String: Any] = [kSecValueData as String: data]
            let s = SecItemUpdate(updateQuery as CFDictionary, attrs as CFDictionary)
            guard s == errSecSuccess else { throw NSError(domain: "KeychainStore", code: Int(s)) }
        } else if status != errSecSuccess {
            throw NSError(domain: "KeychainStore", code: Int(status))
        }
    }
}
