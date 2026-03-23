import Foundation
import Security

final class TokenStore {
    static let shared = TokenStore()

    private let accessTokenKey = "com.fondr.accessToken"
    private let refreshTokenKey = "com.fondr.refreshToken"
    private let userIdKey = "com.fondr.userId"

    private init() {}

    var accessToken: String? {
        get { read(key: accessTokenKey) }
        set {
            if let newValue {
                save(key: accessTokenKey, value: newValue)
            } else {
                delete(key: accessTokenKey)
            }
        }
    }

    var refreshToken: String? {
        get { read(key: refreshTokenKey) }
        set {
            if let newValue {
                save(key: refreshTokenKey, value: newValue)
            } else {
                delete(key: refreshTokenKey)
            }
        }
    }

    var userId: String? {
        get { read(key: userIdKey) }
        set {
            if let newValue {
                save(key: userIdKey, value: newValue)
            } else {
                delete(key: userIdKey)
            }
        }
    }

    var isLoggedIn: Bool {
        accessToken != nil
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        userId = nil
    }

    // MARK: - Keychain

    private func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
