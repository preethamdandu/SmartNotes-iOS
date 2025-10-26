import Foundation
import LocalAuthentication
import Combine
import Security

// MARK: - Authentication Service

class AuthenticationService: AuthenticationServiceProtocol {
    private let isAuthenticatedSubject = CurrentValueSubject<Bool, Never>(false)
    
    var isAuthenticatedPublisher: AnyPublisher<Bool, Never> {
        isAuthenticatedSubject.eraseToAnyPublisher()
    }
    
    func authenticateWithBiometrics() async throws {
        let context = LAContext()
        var error: NSError?
        
        // Check if biometric authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw AuthenticationError.biometricsNotAvailable(error?.localizedDescription)
        }
        
        // Evaluate biometric authentication
        let reason = "Authenticate to access your encrypted notes"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                await MainActor.run {
                    self.isAuthenticatedSubject.send(true)
                }
            } else {
                throw AuthenticationError.authenticationFailed
            }
        } catch {
            throw AuthenticationError.authenticationFailed
        }
    }
    
    func logout() async throws {
        await MainActor.run {
            self.isAuthenticatedSubject.send(false)
        }
    }
}

// MARK: - Encryption Service

class EncryptionService {
    private let keychain = KeychainService()
    
    func encryptNote(_ note: Note) throws -> Data {
        let jsonData = try JSONEncoder().encode(note)
        return try encryptData(jsonData)
    }
    
    func decryptNote(_ encryptedData: Data) throws -> Note {
        let decryptedData = try decryptData(encryptedData)
        return try JSONDecoder().decode(Note.self, from: decryptedData)
    }
    
    private func encryptData(_ data: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        
        let cryptedData = try data.withUnsafeBytes { dataBytes in
            try key.withUnsafeBytes { keyBytes in
                var cryptedData = Data(count: data.count + kCCBlockSizeAES128)
                var numBytesEncrypted: size_t = 0
                
                let cryptStatus = crypt(
                    CCOperation(kCCEncrypt),
                    CCAlgorithm(kCCAlgorithmAES128),
                    CCOptions(kCCOptionPKCS7Padding),
                    keyBytes.bindMemory(to: UInt8.self).baseAddress,
                    kCCKeySizeAES256,
                    nil,
                    dataBytes.bindMemory(to: UInt8.self).baseAddress,
                    data.count,
                    cryptedData.withUnsafeMutableBytes { $0.bindMemory(to: UInt8.self).baseAddress },
                    cryptedData.count,
                    &numBytesEncrypted
                )
                
                guard cryptStatus == kCCSuccess else {
                    throw EncryptionError.encryptionFailed
                }
                
                cryptedData.removeSubrange(numBytesEncrypted..<cryptedData.count)
                return cryptedData
            }
        }
        
        return cryptedData
    }
    
    private func decryptData(_ encryptedData: Data) throws -> Data {
        let key = try getOrCreateEncryptionKey()
        
        let decryptedData = try encryptedData.withUnsafeBytes { encryptedBytes in
            try key.withUnsafeBytes { keyBytes in
                var decryptedData = Data(count: encryptedData.count + kCCBlockSizeAES128)
                var numBytesDecrypted: size_t = 0
                
                let cryptStatus = crypt(
                    CCOperation(kCCDecrypt),
                    CCAlgorithm(kCCAlgorithmAES128),
                    CCOptions(kCCOptionPKCS7Padding),
                    keyBytes.bindMemory(to: UInt8.self).baseAddress,
                    kCCKeySizeAES256,
                    nil,
                    encryptedBytes.bindMemory(to: UInt8.self).baseAddress,
                    encryptedData.count,
                    decryptedData.withUnsafeMutableBytes { $0.bindMemory(to: UInt8.self).baseAddress },
                    decryptedData.count,
                    &numBytesDecrypted
                )
                
                guard cryptStatus == kCCSuccess else {
                    throw EncryptionError.decryptionFailed
                }
                
                decryptedData.removeSubrange(numBytesDecrypted..<decryptedData.count)
                return decryptedData
            }
        }
        
        return decryptedData
    }
    
    private func getOrCreateEncryptionKey() throws -> Data {
        let keyTag = "com.apple.smartnotes.encryption.key"
        
        // Try to retrieve existing key
        if let existingKey = try? keychain.getData(for: keyTag) {
            return existingKey
        }
        
        // Generate new key
        var keyData = Data(count: kCCKeySizeAES256)
        let result = keyData.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, kCCKeySizeAES256, mutableBytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw EncryptionError.keyGenerationFailed
        }
        
        // Store key in keychain
        try keychain.setData(keyData, for: keyTag)
        
        return keyData
    }
}

// MARK: - Keychain Service

class KeychainService {
    func setData(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.addFailed(status)
        }
    }
    
    func getData(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            throw KeychainError.notFound
        }
        
        return data
    }
    
    func deleteData(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - Errors

enum AuthenticationError: Error, LocalizedError {
    case biometricsNotAvailable(String?)
    case authenticationFailed
    case userCanceled
    
    var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable(let message):
            return "Biometric authentication not available: \(message ?? "Unknown error")"
        case .authenticationFailed:
            return "Authentication failed"
        case .userCanceled:
            return "Authentication canceled by user"
        }
    }
}

enum EncryptionError: Error, LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        }
    }
}

enum KeychainError: Error, LocalizedError {
    case addFailed(OSStatus)
    case notFound
    case deleteFailed(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .addFailed(let status):
            return "Failed to add item to keychain: \(status)"
        case .notFound:
            return "Item not found in keychain"
        case .deleteFailed(let status):
            return "Failed to delete item from keychain: \(status)"
        }
    }
}
