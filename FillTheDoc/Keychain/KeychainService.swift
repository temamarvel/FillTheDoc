import Foundation
import Security

/// Ошибки низкоуровневого слоя работы с Keychain.
enum KeychainError: Error, LocalizedError {
    case unexpectedStatus(OSStatus)
    case invalidData
    case stringEncoding
    
    var errorDescription: String? {
        switch self {
            case .unexpectedStatus(let status):
                return "Keychain error: \(status)"
            case .invalidData:
                return "Keychain returned invalid data"
            case .stringEncoding:
                return "Keychain string encoding error"
        }
    }
}

/// Низкоуровневый сервис Keychain: хранение/чтение/удаление значений по `account`.
///
/// Это infrastructure-слой без знания о UI и без привязки к конкретному типу секрета.
/// `APIKeyStore` строит поверх него уже прикладочное поведение для ключа OpenAI.
///
/// Сервис intentionally generic: сегодня он используется для OpenAI API key,
/// но сам по себе не знает ничего о конкретном секрете и может переиспользоваться шире.
actor KeychainService {
    private let service: String
    
    init(service: String = Bundle.main.bundleIdentifier ?? "FillTheDoc") {
        self.service = service
    }
    
    func saveString(_ value: String, account: String) throws {
        guard let data = value.data(using: .utf8) else { throw KeychainError.stringEncoding }
        
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Сначала пробуем update, чтобы не плодить дубликаты для одного account.
        let attributesToUpdate: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributesToUpdate as CFDictionary)
        
        if updateStatus == errSecSuccess {
            return
        }
        
        if updateStatus != errSecItemNotFound {
            throw KeychainError.unexpectedStatus(updateStatus)
        }
        
        // Если item ещё не существует — добавляем новый.
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    }
    
    func loadString(account: String) throws -> String? {
        // Возвращаем `nil`, если секрета нет вовсе; это нормальный сценарий для первого запуска.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
        guard let data = item as? Data else { throw KeychainError.invalidData }
        
        return String(data: data, encoding: .utf8)
    }
    
    func delete(account: String) throws {
        // Удаление отсутствующего item не считается ошибкой прикладного уровня.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
