import Foundation
import LocalAuthentication
import Security
import Combine
import os.log

// MARK: - Enhanced Biometric Authentication Service

class EnhancedBiometricAuthenticationService {
    private let logger = Logger(subsystem: "com.apple.smartnotes", category: "biometric.auth")
    private let keychain = KeychainService()
    
    // Authentication state management
    private let authenticationStateSubject = CurrentValueSubject<AuthenticationState, Never>(.notAuthenticated)
    private let biometricTypeSubject = CurrentValueSubject<BiometricType, Never>(.none)
    
    // Security settings
    private let maxAttempts = 3
    private let lockoutDuration: TimeInterval = 300 // 5 minutes
    private let sessionTimeout: TimeInterval = 600 // 10 minutes
    
    // Attempt tracking
    private var failedAttempts = 0
    private var lastFailedAttempt: Date?
    private var sessionStartTime: Date?
    
    // Publishers
    var authenticationStatePublisher: AnyPublisher<AuthenticationState, Never> {
        authenticationStateSubject.eraseToAnyPublisher()
    }
    
    var biometricTypePublisher: AnyPublisher<BiometricType, Never> {
        biometricTypeSubject.eraseToAnyPublisher()
    }
    
    init() {
        updateBiometricType()
        checkAuthenticationState()
    }
    
    // MARK: - Biometric Type Detection
    
    private func updateBiometricType() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricTypeSubject.send(.faceID)
            case .touchID:
                biometricTypeSubject.send(.touchID)
            case .opticID:
                biometricTypeSubject.send(.opticID)
            default:
                biometricTypeSubject.send(.none)
            }
        } else {
            biometricTypeSubject.send(.none)
        }
    }
    
    // MARK: - Authentication Methods
    
    func authenticateWithBiometrics() async throws -> AuthenticationResult {
        logger.info("Starting biometric authentication")
        
        // Check if biometrics are available
        guard isBiometricAuthenticationAvailable() else {
            logger.warning("Biometric authentication not available")
            throw AuthenticationError.biometricsNotAvailable
        }
        
        // Check for lockout
        if isLockedOut() {
            logger.warning("Authentication locked out due to failed attempts")
            throw AuthenticationError.lockedOut(lockoutRemainingTime())
        }
        
        // Check session timeout
        if isSessionExpired() {
            logger.info("Authentication session expired")
            authenticationStateSubject.send(.notAuthenticated)
        }
        
        let context = LAContext()
        var error: NSError?
        
        // Configure context for better error handling
        context.localizedFallbackTitle = "Use Passcode"
        context.localizedCancelTitle = "Cancel"
        
        // Check policy availability
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            logger.error("Cannot evaluate biometric policy: \(error?.localizedDescription ?? "Unknown error")")
            throw AuthenticationError.biometricsNotAvailable
        }
        
        let reason = getLocalizedReason()
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            if success {
                await handleSuccessfulAuthentication()
                logger.info("Biometric authentication successful")
                return .success
            } else {
                await handleFailedAuthentication()
                logger.warning("Biometric authentication failed")
                return .failed
            }
            
        } catch let error as LAError {
            logger.error("Biometric authentication error: \(error.localizedDescription)")
            return try await handleLAError(error)
        } catch {
            logger.error("Unexpected authentication error: \(error.localizedDescription)")
            await handleFailedAuthentication()
            throw AuthenticationError.authenticationFailed
        }
    }
    
    func authenticateWithPasscode() async throws -> AuthenticationResult {
        logger.info("Starting passcode authentication")
        
        let context = LAContext()
        var error: NSError?
        
        // Check if passcode authentication is available
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            logger.error("Passcode authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            throw AuthenticationError.passcodeNotAvailable
        }
        
        let reason = "Enter your passcode to access encrypted notes"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            
            if success {
                await handleSuccessfulAuthentication()
                logger.info("Passcode authentication successful")
                return .success
            } else {
                await handleFailedAuthentication()
                logger.warning("Passcode authentication failed")
                return .failed
            }
            
        } catch let error as LAError {
            logger.error("Passcode authentication error: \(error.localizedDescription)")
            return try await handleLAError(error)
        } catch {
            logger.error("Unexpected passcode authentication error: \(error.localizedDescription)")
            await handleFailedAuthentication()
            throw AuthenticationError.authenticationFailed
        }
    }
    
    func authenticateWithCustomPasscode(_ passcode: String) async throws -> AuthenticationResult {
        logger.info("Starting custom passcode authentication")
        
        // Verify passcode against stored hash
        let storedHash = try keychain.getData(for: "custom_passcode_hash")
        let inputHash = try hashPasscode(passcode)
        
        if storedHash == inputHash {
            await handleSuccessfulAuthentication()
            logger.info("Custom passcode authentication successful")
            return .success
        } else {
            await handleFailedAuthentication()
            logger.warning("Custom passcode authentication failed")
            return .failed
        }
    }
    
    // MARK: - Progressive Authentication
    
    func authenticateWithProgressiveFallback() async throws -> AuthenticationResult {
        logger.info("Starting progressive authentication fallback")
        
        // Try biometrics first
        do {
            let result = try await authenticateWithBiometrics()
            if result == .success {
                return result
            }
        } catch AuthenticationError.biometricsNotAvailable {
            logger.info("Biometrics not available, trying passcode")
        } catch AuthenticationError.lockedOut {
            logger.info("Biometrics locked out, trying passcode")
        } catch {
            logger.info("Biometric authentication failed, trying passcode")
        }
        
        // Try passcode fallback
        do {
            let result = try await authenticateWithPasscode()
            if result == .success {
                return result
            }
        } catch AuthenticationError.passcodeNotAvailable {
            logger.info("Passcode not available, trying custom passcode")
        } catch {
            logger.info("Passcode authentication failed, trying custom passcode")
        }
        
        // Try custom passcode fallback
        do {
            let result = try await authenticateWithCustomPasscode("")
            return result
        } catch {
            logger.error("All authentication methods failed")
            throw AuthenticationError.allMethodsFailed
        }
    }
    
    // MARK: - Error Handling
    
    private func handleLAError(_ error: LAError) async throws -> AuthenticationResult {
        switch error.code {
        case .authenticationFailed:
            await handleFailedAuthentication()
            return .failed
            
        case .userCancel:
            logger.info("User canceled authentication")
            return .canceled
            
        case .userFallback:
            logger.info("User chose fallback authentication")
            return .fallbackRequested
            
        case .systemCancel:
            logger.info("System canceled authentication")
            return .canceled
            
        case .passcodeNotSet:
            logger.warning("Passcode not set on device")
            throw AuthenticationError.passcodeNotSet
            
        case .biometryNotAvailable:
            logger.warning("Biometry not available on device")
            throw AuthenticationError.biometricsNotAvailable
            
        case .biometryNotEnrolled:
            logger.warning("Biometry not enrolled on device")
            throw AuthenticationError.biometricsNotEnrolled
            
        case .biometryLockout:
            logger.warning("Biometry locked out")
            await handleLockout()
            throw AuthenticationError.biometricsLockedOut
            
        case .notInteractive:
            logger.warning("Authentication not interactive")
            throw AuthenticationError.notInteractive
            
        case .appCancel:
            logger.info("App canceled authentication")
            return .canceled
            
        case .invalidContext:
            logger.error("Invalid authentication context")
            throw AuthenticationError.invalidContext
            
        case .notDetermined:
            logger.warning("Biometry not determined")
            throw AuthenticationError.biometricsNotDetermined
            
        default:
            logger.error("Unknown LAError: \(error.localizedDescription)")
            await handleFailedAuthentication()
            throw AuthenticationError.authenticationFailed
        }
    }
    
    // MARK: - Authentication State Management
    
    private func handleSuccessfulAuthentication() async {
        failedAttempts = 0
        lastFailedAttempt = nil
        sessionStartTime = Date()
        authenticationStateSubject.send(.authenticated)
        
        // Store authentication timestamp
        try? keychain.setData(Date().timeIntervalSince1970.data, for: "last_auth_time")
    }
    
    private func handleFailedAuthentication() async {
        failedAttempts += 1
        lastFailedAttempt = Date()
        
        logger.warning("Authentication failed. Attempt \(failedAttempts)/\(maxAttempts)")
        
        if failedAttempts >= maxAttempts {
            await handleLockout()
        }
    }
    
    private func handleLockout() async {
        logger.warning("Authentication locked out due to \(failedAttempts) failed attempts")
        authenticationStateSubject.send(.lockedOut)
        
        // Store lockout timestamp
        try? keychain.setData(Date().timeIntervalSince1970.data, for: "lockout_time")
    }
    
    // MARK: - Security Checks
    
    private func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    private func isLockedOut() -> Bool {
        guard let lockoutTime = try? keychain.getData(for: "lockout_time"),
              let timestamp = Double(data: lockoutTime) else {
            return false
        }
        
        let lockoutDate = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(lockoutDate) < lockoutDuration
    }
    
    private func lockoutRemainingTime() -> TimeInterval {
        guard let lockoutTime = try? keychain.getData(for: "lockout_time"),
              let timestamp = Double(data: lockoutTime) else {
            return 0
        }
        
        let lockoutDate = Date(timeIntervalSince1970: timestamp)
        let elapsed = Date().timeIntervalSince(lockoutDate)
        return max(0, lockoutDuration - elapsed)
    }
    
    private func isSessionExpired() -> Bool {
        guard let sessionStart = sessionStartTime else { return true }
        return Date().timeIntervalSince(sessionStart) > sessionTimeout
    }
    
    private func checkAuthenticationState() {
        if isSessionExpired() {
            authenticationStateSubject.send(.notAuthenticated)
        } else if isLockedOut() {
            authenticationStateSubject.send(.lockedOut)
        } else {
            authenticationStateSubject.send(.authenticated)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getLocalizedReason() -> String {
        let biometricType = biometricTypeSubject.value
        
        switch biometricType {
        case .faceID:
            return "Use Face ID to access your encrypted notes"
        case .touchID:
            return "Use Touch ID to access your encrypted notes"
        case .opticID:
            return "Use Optic ID to access your encrypted notes"
        case .none:
            return "Authenticate to access your encrypted notes"
        }
    }
    
    private func hashPasscode(_ passcode: String) throws -> Data {
        let salt = try keychain.getData(for: "passcode_salt") ?? generateSalt()
        try keychain.setData(salt, for: "passcode_salt")
        
        let data = (passcode + String(data: salt, encoding: .utf8)!).data(using: .utf8)!
        return SHA256.hash(data: data)
    }
    
    private func generateSalt() -> Data {
        var salt = Data(count: 32)
        let result = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        return result == errSecSuccess ? salt : Data()
    }
    
    // MARK: - Public Methods
    
    func logout() async {
        logger.info("User logged out")
        authenticationStateSubject.send(.notAuthenticated)
        sessionStartTime = nil
    }
    
    func resetFailedAttempts() async {
        logger.info("Resetting failed attempts")
        failedAttempts = 0
        lastFailedAttempt = nil
        try? keychain.deleteData(for: "lockout_time")
    }
    
    func isAuthenticated() -> Bool {
        return authenticationStateSubject.value == .authenticated && !isSessionExpired()
    }
    
    func getRemainingAttempts() -> Int {
        return max(0, maxAttempts - failedAttempts)
    }
}

// MARK: - Supporting Types

enum AuthenticationState {
    case notAuthenticated
    case authenticated
    case lockedOut
    case expired
}

enum BiometricType {
    case faceID
    case touchID
    case opticID
    case none
}

enum AuthenticationResult {
    case success
    case failed
    case canceled
    case fallbackRequested
}

enum AuthenticationError: Error, LocalizedError {
    case biometricsNotAvailable
    case biometricsNotEnrolled
    case biometricsLockedOut
    case biometricsNotDetermined
    case passcodeNotAvailable
    case passcodeNotSet
    case authenticationFailed
    case lockedOut(TimeInterval)
    case notInteractive
    case invalidContext
    case allMethodsFailed
    
    var errorDescription: String? {
        switch self {
        case .biometricsNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricsNotEnrolled:
            return "No biometric data is enrolled. Please set up Face ID or Touch ID in Settings."
        case .biometricsLockedOut:
            return "Biometric authentication is locked out. Please use your passcode."
        case .biometricsNotDetermined:
            return "Biometric authentication status is not determined"
        case .passcodeNotAvailable:
            return "Passcode authentication is not available"
        case .passcodeNotSet:
            return "No passcode is set on this device"
        case .authenticationFailed:
            return "Authentication failed. Please try again."
        case .lockedOut(let remainingTime):
            return "Too many failed attempts. Try again in \(Int(remainingTime)) seconds."
        case .notInteractive:
            return "Authentication is not interactive"
        case .invalidContext:
            return "Invalid authentication context"
        case .allMethodsFailed:
            return "All authentication methods failed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .biometricsNotAvailable, .biometricsNotEnrolled:
            return "Please set up Face ID or Touch ID in Settings > Face ID & Passcode"
        case .biometricsLockedOut:
            return "Use your device passcode to unlock biometric authentication"
        case .passcodeNotSet:
            return "Please set a passcode in Settings > Face ID & Passcode"
        case .lockedOut:
            return "Wait for the lockout period to expire before trying again"
        case .allMethodsFailed:
            return "Please contact support if you continue to have authentication issues"
        default:
            return "Please try again or use an alternative authentication method"
        }
    }
}

// MARK: - Data Extension

extension Data {
    init<T>(from value: T) {
        var value = value
        self.init(buffer: UnsafeBufferPointer(start: &value, count: 1))
    }
    
    func to<T>(type: T.Type) -> T {
        return self.withUnsafeBytes { $0.load(as: T.self) }
    }
}

extension Double {
    init?(data: Data) {
        guard data.count == MemoryLayout<Double>.size else { return nil }
        self = data.to(type: Double.self)
    }
}

// MARK: - SHA256 Extension

import CryptoKit

extension SHA256 {
    static func hash(data: Data) -> Data {
        let hash = SHA256.hash(data: data)
        return Data(hash)
    }
}
