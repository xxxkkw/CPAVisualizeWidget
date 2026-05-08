import Foundation
import Security

struct KeychainStore {
    enum KeychainError: Error {
        case unexpectedStatus(OSStatus)
        case invalidData
    }

    private let service: String

    init(service: String) {
        self.service = service
    }

    func saveString(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        try saveData(data, for: key)
    }

    func loadString(for key: String) throws -> String? {
        guard let data = try loadData(for: key) else {
            return nil
        }

        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    func deleteValue(for key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    private func saveData(_ data: Data, for key: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        var insertQuery = query
        insertQuery[kSecValueData] = data
        let insertStatus = SecItemAdd(insertQuery as CFDictionary, nil)
        guard insertStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(insertStatus)
        }
    }

    private func loadData(for key: String) throws -> Data? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainError.invalidData
            }
            return data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }
}