import Foundation
import Security

protocol KeychainStoring {
    func data(for key: String) -> Data?
    func set(data: Data, for key: String)
    func deleteData(for key: String)
}

final class KeychainStore: KeychainStoring {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func data(for key: String) -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    func set(data: Data, for key: String) {
        deleteData(for: key)
        var query = baseQuery(key)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(query as CFDictionary, nil)
    }

    func deleteData(for key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}

final class MemoryKeychainStore: KeychainStoring {
    private var values: [String: Data] = [:]

    func data(for key: String) -> Data? { values[key] }
    func set(data: Data, for key: String) { values[key] = data }
    func deleteData(for key: String) { values.removeValue(forKey: key) }
}
