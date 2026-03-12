import Foundation
import Security

/// Safe storage for SSH passwords in macOS Keychain.
/// Passwords are stored as generic passwords keyed by tunnel UUID.
enum KeychainHelper {

    private static let service = "SSHTunnel Pro"

    static func savePassword(_ password: String, forID id: UUID) {
        guard let data = password.data(using: .utf8) else { return }
        let account = id.uuidString

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attrs: [CFString: Any] = [kSecValueData: data]

        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func getPassword(forID id: UUID) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: id.uuidString,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deletePassword(forID id: UUID) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: id.uuidString
        ]
        SecItemDelete(query as CFDictionary)
    }
}
