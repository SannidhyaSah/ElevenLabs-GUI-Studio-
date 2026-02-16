import Foundation
import Security

// MARK: - Keychain Service

/// Manages API key storage using the macOS Keychain.
/// Each key is stored as a generic password with the key name as the account.
struct KeychainService {
    
    private static let service = "com.elevenlabs.gui.studio"
    
    // MARK: - API Key CRUD
    
    /// Save or update an API key in the Keychain.
    static func saveAPIKey(_ apiKey: String, name: String) throws {
        let data = Data(apiKey.utf8)
        
        // Check if key already exists
        if retrieveAPIKey(name: name) != nil {
            // Update existing
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: name
            ]
            let attributes: [String: Any] = [
                kSecValueData as String: data
            ]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw KeychainError.updateFailed(status)
            }
        } else {
            // Add new
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: name,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw KeychainError.saveFailed(status)
            }
        }
    }
    
    /// Retrieve an API key from the Keychain by name.
    static func retrieveAPIKey(name: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Delete an API key from the Keychain.
    static func deleteAPIKey(name: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: name
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
    
    /// List all saved API key names.
    static func listAPIKeyNames() -> [String] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return []
        }
        
        return items.compactMap { $0[kSecAttrAccount as String] as? String }
            .sorted()
    }
    
    // MARK: - Current API Key Name (UserDefaults)
    
    private static let currentKeyNameKey = "currentAPIKeyName"
    
    /// Get the name of the currently active API key.
    static var currentAPIKeyName: String? {
        get { UserDefaults.standard.string(forKey: currentKeyNameKey) }
        set { UserDefaults.standard.set(newValue, forKey: currentKeyNameKey) }
    }
    
    /// Get the currently active API key value.
    static var currentAPIKey: String? {
        guard let name = currentAPIKeyName else { return nil }
        return retrieveAPIKey(name: name)
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case saveFailed(OSStatus)
    case updateFailed(OSStatus)
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save API key to Keychain (status: \(status))"
        case .updateFailed(let status):
            return "Failed to update API key in Keychain (status: \(status))"
        case .deleteFailed(let status):
            return "Failed to delete API key from Keychain (status: \(status))"
        }
    }
}
