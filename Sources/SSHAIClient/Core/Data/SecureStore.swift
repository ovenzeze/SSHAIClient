import Foundation
import CryptoKit

struct SecureStore {
    static func getKey() throws -> SymmetricKey {
        // Use Keychain-backed symmetric key
        return try KeychainStore.getOrCreateKey()
    }
}
