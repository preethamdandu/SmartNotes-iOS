import Foundation
import UIKit
import LocalAuthentication
import Security

// MARK: - Security Manager

class SecurityManager {
    static let shared = SecurityManager()
    
    private let keychain = KeychainService()
    private let encryptionService = EncryptionService()
    private let authService = AuthenticationService()
    
    private init() {}
    
    // MARK: - Biometric Authentication
    
    func isBiometricAuthenticationAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
    
    func authenticateWithBiometrics() async throws {
        try await authService.authenticateWithBiometrics()
    }
    
    // MARK: - Note Encryption
    
    func encryptNote(_ note: Note) throws -> Data {
        return try encryptionService.encryptNote(note)
    }
    
    func decryptNote(_ encryptedData: Data) throws -> Note {
        return try encryptionService.decryptNote(encryptedData)
    }
    
    // MARK: - Secure Storage
    
    func storeSecureData(_ data: Data, forKey key: String) throws {
        try keychain.setData(data, for: key)
    }
    
    func retrieveSecureData(forKey key: String) throws -> Data {
        return try keychain.getData(for: key)
    }
    
    func deleteSecureData(forKey key: String) throws {
        try keychain.deleteData(for: key)
    }
    
    // MARK: - Security Settings
    
    func isEncryptionEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "encryptionEnabled")
    }
    
    func setEncryptionEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "encryptionEnabled")
    }
    
    func isBiometricEnabled() -> Bool {
        return UserDefaults.standard.bool(forKey: "biometricEnabled")
    }
    
    func setBiometricEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "biometricEnabled")
    }
    
    func getAutoLockTimeout() -> TimeInterval {
        let timeout = UserDefaults.standard.double(forKey: "autoLockTimeout")
        return timeout > 0 ? timeout : 300 // Default 5 minutes
    }
    
    func setAutoLockTimeout(_ timeout: TimeInterval) {
        UserDefaults.standard.set(timeout, forKey: "autoLockTimeout")
    }
}

// MARK: - Enhanced Encryption Service

extension EncryptionService {
    
    /// Encrypts sensitive note content with additional security measures
    func encryptSensitiveContent(_ content: String) throws -> Data {
        guard let data = content.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        
        // Add salt and IV for additional security
        let salt = try generateRandomBytes(count: 32)
        let iv = try generateRandomBytes(count: 16)
        
        let key = try deriveKey(from: salt)
        let encryptedData = try encryptDataWithIV(data, key: key, iv: iv)
        
        // Combine salt + iv + encrypted data
        var combinedData = Data()
        combinedData.append(salt)
        combinedData.append(iv)
        combinedData.append(encryptedData)
        
        return combinedData
    }
    
    /// Decrypts sensitive note content
    func decryptSensitiveContent(_ encryptedData: Data) throws -> String {
        guard encryptedData.count > 48 else { // 32 (salt) + 16 (iv) + data
            throw EncryptionError.invalidData
        }
        
        let salt = encryptedData.prefix(32)
        let iv = encryptedData.subdata(in: 32..<48)
        let encryptedContent = encryptedData.suffix(from: 48)
        
        let key = try deriveKey(from: salt)
        let decryptedData = try decryptDataWithIV(encryptedContent, key: key, iv: iv)
        
        guard let content = String(data: decryptedData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed
        }
        
        return content
    }
    
    private func generateRandomBytes(count: Int) throws -> Data {
        var bytes = Data(count: count)
        let result = bytes.withUnsafeMutableBytes { mutableBytes in
            SecRandomCopyBytes(kSecRandomDefault, count, mutableBytes.bindMemory(to: UInt8.self).baseAddress!)
        }
        
        guard result == errSecSuccess else {
            throw EncryptionError.keyGenerationFailed
        }
        
        return bytes
    }
    
    private func deriveKey(from salt: Data) throws -> Data {
        let masterKey = try getOrCreateEncryptionKey()
        
        var derivedKey = Data(count: kCCKeySizeAES256)
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            masterKey.withUnsafeBytes { masterKeyBytes in
                salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        masterKeyBytes.bindMemory(to: Int8.self).baseAddress,
                        masterKey.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        100000, // Iteration count
                        derivedKeyBytes.bindMemory(to: UInt8.self).baseAddress,
                        kCCKeySizeAES256
                    )
                }
            }
        }
        
        guard result == kCCSuccess else {
            throw EncryptionError.keyGenerationFailed
        }
        
        return derivedKey
    }
    
    private func encryptDataWithIV(_ data: Data, key: Data, iv: Data) throws -> Data {
        var encryptedData = Data(count: data.count + kCCBlockSizeAES128)
        var numBytesEncrypted: size_t = 0
        
        let cryptStatus = data.withUnsafeBytes { dataBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    encryptedData.withUnsafeMutableBytes { encryptedBytes in
                        crypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.bindMemory(to: UInt8.self).baseAddress,
                            kCCKeySizeAES256,
                            ivBytes.bindMemory(to: UInt8.self).baseAddress,
                            dataBytes.bindMemory(to: UInt8.self).baseAddress,
                            data.count,
                            encryptedBytes.bindMemory(to: UInt8.self).baseAddress,
                            encryptedData.count,
                            &numBytesEncrypted
                        )
                    }
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else {
            throw EncryptionError.encryptionFailed
        }
        
        encryptedData.removeSubrange(numBytesEncrypted..<encryptedData.count)
        return encryptedData
    }
    
    private func decryptDataWithIV(_ encryptedData: Data, key: Data, iv: Data) throws -> Data {
        var decryptedData = Data(count: encryptedData.count + kCCBlockSizeAES128)
        var numBytesDecrypted: size_t = 0
        
        let cryptStatus = encryptedData.withUnsafeBytes { encryptedBytes in
            key.withUnsafeBytes { keyBytes in
                iv.withUnsafeBytes { ivBytes in
                    decryptedData.withUnsafeMutableBytes { decryptedBytes in
                        crypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES128),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.bindMemory(to: UInt8.self).baseAddress,
                            kCCKeySizeAES256,
                            ivBytes.bindMemory(to: UInt8.self).baseAddress,
                            encryptedBytes.bindMemory(to: UInt8.self).baseAddress,
                            encryptedData.count,
                            decryptedBytes.bindMemory(to: UInt8.self).baseAddress,
                            decryptedData.count,
                            &numBytesDecrypted
                        )
                    }
                }
            }
        }
        
        guard cryptStatus == kCCSuccess else {
            throw EncryptionError.decryptionFailed
        }
        
        decryptedData.removeSubrange(numBytesDecrypted..<decryptedData.count)
        return decryptedData
    }
}

// MARK: - Security Settings View Controller

class SecuritySettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let securityManager = SecurityManager.shared
    
    private enum SecuritySection: Int, CaseIterable {
        case biometrics = 0
        case encryption = 1
        case autoLock = 2
        
        var title: String {
            switch self {
            case .biometrics: return "Biometric Authentication"
            case .encryption: return "Encryption"
            case .autoLock: return "Auto Lock"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "Security Settings"
        view.backgroundColor = .systemGroupedBackground
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: SwitchTableViewCell.identifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - Security Settings Table View

extension SecuritySettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return SecuritySection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let securitySection = SecuritySection(rawValue: section) else { return 0 }
        
        switch securitySection {
        case .biometrics: return securityManager.isBiometricAuthenticationAvailable() ? 1 : 0
        case .encryption: return 1
        case .autoLock: return 1
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let securitySection = SecuritySection(rawValue: section) else { return nil }
        return securitySection.title
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let securitySection = SecuritySection(rawValue: section) else { return nil }
        
        switch securitySection {
        case .biometrics:
            return "Use Touch ID or Face ID to secure your notes"
        case .encryption:
            return "All notes are encrypted using AES-256 encryption"
        case .autoLock:
            return "Automatically lock the app after a period of inactivity"
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let securitySection = SecuritySection(rawValue: indexPath.section) else {
            return tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        }
        
        switch securitySection {
        case .biometrics:
            let cell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.identifier, for: indexPath) as! SwitchTableViewCell
            cell.configure(
                title: "Enable Biometric Authentication",
                isOn: securityManager.isBiometricEnabled(),
                action: { [weak self] isOn in
                    self?.securityManager.setBiometricEnabled(isOn)
                }
            )
            return cell
            
        case .encryption:
            let cell = tableView.dequeueReusableCell(withIdentifier: SwitchTableViewCell.identifier, for: indexPath) as! SwitchTableViewCell
            cell.configure(
                title: "Enable Note Encryption",
                isOn: securityManager.isEncryptionEnabled(),
                action: { [weak self] isOn in
                    self?.securityManager.setEncryptionEnabled(isOn)
                }
            )
            return cell
            
        case .autoLock:
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = "Auto Lock Timeout"
            cell.detailTextLabel?.text = formatAutoLockTimeout(securityManager.getAutoLockTimeout())
            cell.accessoryType = .disclosureIndicator
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let securitySection = SecuritySection(rawValue: indexPath.section) else { return }
        
        if securitySection == .autoLock {
            showAutoLockOptions()
        }
    }
    
    private func formatAutoLockTimeout(_ timeout: TimeInterval) -> String {
        let minutes = Int(timeout / 60)
        if minutes < 1 {
            return "Immediately"
        } else if minutes == 1 {
            return "1 minute"
        } else {
            return "\(minutes) minutes"
        }
    }
    
    private func showAutoLockOptions() {
        let alert = UIAlertController(title: "Auto Lock Timeout", message: "Choose when to automatically lock the app", preferredStyle: .actionSheet)
        
        let timeouts: [(String, TimeInterval)] = [
            ("Immediately", 0),
            ("1 minute", 60),
            ("5 minutes", 300),
            ("15 minutes", 900),
            ("30 minutes", 1800),
            ("1 hour", 3600),
            ("Never", -1)
        ]
        
        for (title, timeout) in timeouts {
            alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                if timeout >= 0 {
                    self?.securityManager.setAutoLockTimeout(timeout)
                    self?.tableView.reloadData()
                }
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - Switch Table View Cell

class SwitchTableViewCell: UITableViewCell {
    static let identifier = "SwitchTableViewCell"
    
    private let titleLabel = UILabel()
    private let switchControl = UISwitch()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        titleLabel.font = UIFont.preferredFont(forTextStyle: .body)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(switchControl)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: switchControl.leadingAnchor, constant: -16),
            
            switchControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            switchControl.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(title: String, isOn: Bool, action: @escaping (Bool) -> Void) {
        titleLabel.text = title
        switchControl.isOn = isOn
        switchControl.removeTarget(nil, action: nil, for: .valueChanged)
        switchControl.addAction(UIAction { _ in
            action(self.switchControl.isOn)
        }, for: .valueChanged)
    }
}

// MARK: - Additional Encryption Errors

extension EncryptionError {
    static let invalidData = EncryptionError.encryptionFailed
}
