import UIKit
import LocalAuthentication
import Combine

// MARK: - Authentication View Controller

class AuthenticationViewController: UIViewController {
    
    // MARK: - UI Components
    
    private let containerView = UIView()
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let biometricButton = UIButton(type: .system)
    private let passcodeButton = UIButton(type: .system)
    private let customPasscodeButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let progressView = UIProgressView()
    private let retryButton = UIButton(type: .system)
    
    // MARK: - Properties
    
    private let authService = EnhancedBiometricAuthenticationService()
    private var cancellables = Set<AnyCancellable>()
    private var isAuthenticating = false
    private var currentAttempts = 0
    private let maxAttempts = 3
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        checkAuthenticationAvailability()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Auto-trigger biometric authentication if available
        if authService.isBiometricAuthenticationAvailable() {
            Task {
                await attemptBiometricAuthentication()
            }
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        setupContainerView()
        setupLogo()
        setupLabels()
        setupButtons()
        setupStatusLabel()
        setupProgressView()
        setupConstraints()
    }
    
    private func setupContainerView() {
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .secondarySystemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        containerView.layer.shadowRadius = 8
        containerView.layer.shadowOpacity = 0.1
        view.addSubview(containerView)
    }
    
    private func setupLogo() {
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.image = UIImage(systemName: "lock.shield")
        logoImageView.tintColor = .systemBlue
        logoImageView.contentMode = .scaleAspectFit
        containerView.addSubview(logoImageView)
    }
    
    private func setupLabels() {
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Smart Notes"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        containerView.addSubview(titleLabel)
        
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Secure your encrypted notes"
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.textColor = .secondaryLabel
        containerView.addSubview(subtitleLabel)
    }
    
    private func setupButtons() {
        // Biometric Button
        biometricButton.translatesAutoresizingMaskIntoConstraints = false
        biometricButton.setTitle("Use Face ID", for: .normal)
        biometricButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        biometricButton.backgroundColor = .systemBlue
        biometricButton.setTitleColor(.white, for: .normal)
        biometricButton.layer.cornerRadius = 12
        biometricButton.addTarget(self, action: #selector(biometricButtonTapped), for: .touchUpInside)
        containerView.addSubview(biometricButton)
        
        // Passcode Button
        passcodeButton.translatesAutoresizingMaskIntoConstraints = false
        passcodeButton.setTitle("Use Passcode", for: .normal)
        passcodeButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        passcodeButton.backgroundColor = .systemGray5
        passcodeButton.setTitleColor(.label, for: .normal)
        passcodeButton.layer.cornerRadius = 8
        passcodeButton.addTarget(self, action: #selector(passcodeButtonTapped), for: .touchUpInside)
        containerView.addSubview(passcodeButton)
        
        // Custom Passcode Button
        customPasscodeButton.translatesAutoresizingMaskIntoConstraints = false
        customPasscodeButton.setTitle("Custom Passcode", for: .normal)
        customPasscodeButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .regular)
        customPasscodeButton.backgroundColor = .clear
        customPasscodeButton.setTitleColor(.systemBlue, for: .normal)
        customPasscodeButton.addTarget(self, action: #selector(customPasscodeButtonTapped), for: .touchUpInside)
        containerView.addSubview(customPasscodeButton)
        
        // Retry Button
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("Try Again", for: .normal)
        retryButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        retryButton.backgroundColor = .systemOrange
        retryButton.setTitleColor(.white, for: .normal)
        retryButton.layer.cornerRadius = 8
        retryButton.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        retryButton.isHidden = true
        containerView.addSubview(retryButton)
    }
    
    private func setupStatusLabel() {
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Choose an authentication method"
        statusLabel.font = .systemFont(ofSize: 14, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        containerView.addSubview(statusLabel)
    }
    
    private func setupProgressView() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = .systemBlue
        progressView.trackTintColor = .systemGray5
        progressView.isHidden = true
        containerView.addSubview(progressView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container View
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            
            // Logo
            logoImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
            logoImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Biometric Button
            biometricButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 32),
            biometricButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            biometricButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            biometricButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Passcode Button
            passcodeButton.topAnchor.constraint(equalTo: biometricButton.bottomAnchor, constant: 16),
            passcodeButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            passcodeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            passcodeButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Custom Passcode Button
            customPasscodeButton.topAnchor.constraint(equalTo: passcodeButton.bottomAnchor, constant: 12),
            customPasscodeButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            customPasscodeButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Status Label
            statusLabel.topAnchor.constraint(equalTo: customPasscodeButton.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            
            // Progress View
            progressView.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            progressView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            progressView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            
            // Retry Button
            retryButton.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 16),
            retryButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            retryButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            retryButton.heightAnchor.constraint(equalToConstant: 44),
            retryButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -24)
        ])
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        // Listen to biometric type changes
        authService.biometricTypePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] biometricType in
                self?.updateBiometricButton(for: biometricType)
            }
            .store(in: &cancellables)
        
        // Listen to authentication state changes
        authService.authenticationStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleAuthenticationStateChange(state)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Authentication Methods
    
    @objc private func biometricButtonTapped() {
        Task {
            await attemptBiometricAuthentication()
        }
    }
    
    @objc private func passcodeButtonTapped() {
        Task {
            await attemptPasscodeAuthentication()
        }
    }
    
    @objc private func customPasscodeButtonTapped() {
        showCustomPasscodeAlert()
    }
    
    @objc private func retryButtonTapped() {
        Task {
            await attemptBiometricAuthentication()
        }
    }
    
    // MARK: - Authentication Implementation
    
    private func attemptBiometricAuthentication() async {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        updateUIForAuthentication(isAuthenticating: true)
        
        do {
            let result = try await authService.authenticateWithBiometrics()
            await handleAuthenticationResult(result)
        } catch let error as AuthenticationError {
            await handleAuthenticationError(error)
        } catch {
            await handleGenericError(error)
        }
        
        isAuthenticating = false
        updateUIForAuthentication(isAuthenticating: false)
    }
    
    private func attemptPasscodeAuthentication() async {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        updateUIForAuthentication(isAuthenticating: true)
        
        do {
            let result = try await authService.authenticateWithPasscode()
            await handleAuthenticationResult(result)
        } catch let error as AuthenticationError {
            await handleAuthenticationError(error)
        } catch {
            await handleGenericError(error)
        }
        
        isAuthenticating = false
        updateUIForAuthentication(isAuthenticating: false)
    }
    
    private func attemptCustomPasscodeAuthentication(_ passcode: String) async {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        updateUIForAuthentication(isAuthenticating: true)
        
        do {
            let result = try await authService.authenticateWithCustomPasscode(passcode)
            await handleAuthenticationResult(result)
        } catch let error as AuthenticationError {
            await handleAuthenticationError(error)
        } catch {
            await handleGenericError(error)
        }
        
        isAuthenticating = false
        updateUIForAuthentication(isAuthenticating: false)
    }
    
    // MARK: - Result Handling
    
    private func handleAuthenticationResult(_ result: AuthenticationResult) async {
        await MainActor.run {
            switch result {
            case .success:
                showSuccessAndDismiss()
            case .failed:
                handleFailedAttempt()
            case .canceled:
                statusLabel.text = "Authentication canceled"
                statusLabel.textColor = .systemOrange
            case .fallbackRequested:
                showFallbackOptions()
            }
        }
    }
    
    private func handleAuthenticationError(_ error: AuthenticationError) async {
        await MainActor.run {
            statusLabel.text = error.localizedDescription
            statusLabel.textColor = .systemRed
            
            // Show recovery suggestion if available
            if let suggestion = error.recoverySuggestion {
                showAlert(title: "Authentication Error", message: suggestion)
            }
            
            // Handle specific error types
            switch error {
            case .lockedOut(let remainingTime):
                showLockoutAlert(remainingTime: remainingTime)
            case .biometricsNotAvailable, .biometricsNotEnrolled:
                hideBiometricButton()
            case .passcodeNotSet:
                showPasscodeSetupAlert()
            default:
                break
            }
        }
    }
    
    private func handleGenericError(_ error: Error) async {
        await MainActor.run {
            statusLabel.text = "An unexpected error occurred"
            statusLabel.textColor = .systemRed
            showAlert(title: "Error", message: error.localizedDescription)
        }
    }
    
    // MARK: - UI Updates
    
    private func updateUIForAuthentication(isAuthenticating: Bool) {
        DispatchQueue.main.async {
            self.biometricButton.isEnabled = !isAuthenticating
            self.passcodeButton.isEnabled = !isAuthenticating
            self.customPasscodeButton.isEnabled = !isAuthenticating
            
            if isAuthenticating {
                self.progressView.isHidden = false
                self.progressView.progress = 0.0
                self.animateProgress()
            } else {
                self.progressView.isHidden = true
            }
        }
    }
    
    private func animateProgress() {
        UIView.animate(withDuration: 2.0, delay: 0, options: [.repeat, .autoreverse]) {
            self.progressView.progress = 1.0
        }
    }
    
    private func updateBiometricButton(for biometricType: BiometricType) {
        DispatchQueue.main.async {
            switch biometricType {
            case .faceID:
                self.biometricButton.setTitle("Use Face ID", for: .normal)
                self.biometricButton.setImage(UIImage(systemName: "faceid"), for: .normal)
            case .touchID:
                self.biometricButton.setTitle("Use Touch ID", for: .normal)
                self.biometricButton.setImage(UIImage(systemName: "touchid"), for: .normal)
            case .opticID:
                self.biometricButton.setTitle("Use Optic ID", for: .normal)
                self.biometricButton.setImage(UIImage(systemName: "opticid"), for: .normal)
            case .none:
                self.biometricButton.isHidden = true
            }
        }
    }
    
    private func handleAuthenticationStateChange(_ state: AuthenticationState) {
        DispatchQueue.main.async {
            switch state {
            case .notAuthenticated:
                self.statusLabel.text = "Please authenticate to continue"
                self.statusLabel.textColor = .secondaryLabel
            case .authenticated:
                self.showSuccessAndDismiss()
            case .lockedOut:
                self.statusLabel.text = "Too many failed attempts. Please try again later."
                self.statusLabel.textColor = .systemRed
                self.showRetryButton()
            case .expired:
                self.statusLabel.text = "Session expired. Please authenticate again."
                self.statusLabel.textColor = .systemOrange
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkAuthenticationAvailability() {
        if !authService.isBiometricAuthenticationAvailable() {
            hideBiometricButton()
        }
    }
    
    private func hideBiometricButton() {
        DispatchQueue.main.async {
            self.biometricButton.isHidden = true
            self.passcodeButton.topAnchor.constraint(equalTo: self.subtitleLabel.bottomAnchor, constant: 32).isActive = true
        }
    }
    
    private func showRetryButton() {
        DispatchQueue.main.async {
            self.retryButton.isHidden = false
        }
    }
    
    private func handleFailedAttempt() {
        currentAttempts += 1
        statusLabel.text = "Authentication failed. \(maxAttempts - currentAttempts) attempts remaining."
        statusLabel.textColor = .systemRed
        
        if currentAttempts >= maxAttempts {
            showRetryButton()
        }
    }
    
    private func showSuccessAndDismiss() {
        statusLabel.text = "Authentication successful!"
        statusLabel.textColor = .systemGreen
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.dismiss(animated: true)
        }
    }
    
    private func showFallbackOptions() {
        let alert = UIAlertController(title: "Authentication Failed", message: "Would you like to try a different method?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Use Passcode", style: .default) { _ in
            Task {
                await self.attemptPasscodeAuthentication()
            }
        })
        
        alert.addAction(UIAlertAction(title: "Custom Passcode", style: .default) { _ in
            self.showCustomPasscodeAlert()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showCustomPasscodeAlert() {
        let alert = UIAlertController(title: "Custom Passcode", message: "Enter your custom passcode", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Enter passcode"
            textField.isSecureTextEntry = true
        }
        
        alert.addAction(UIAlertAction(title: "Authenticate", style: .default) { _ in
            guard let passcode = alert.textFields?.first?.text, !passcode.isEmpty else { return }
            Task {
                await self.attemptCustomPasscodeAuthentication(passcode)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showLockoutAlert(remainingTime: TimeInterval) {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        
        let message = "Too many failed attempts. Please try again in \(minutes):\(String(format: "%02d", seconds))."
        showAlert(title: "Locked Out", message: message)
    }
    
    private func showPasscodeSetupAlert() {
        showAlert(title: "Passcode Required", message: "Please set up a passcode in Settings > Face ID & Passcode to use this feature.")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Authentication Manager

class AuthenticationManager {
    static let shared = AuthenticationManager()
    
    private let authService = EnhancedBiometricAuthenticationService()
    private var authenticationViewController: AuthenticationViewController?
    
    private init() {}
    
    func presentAuthenticationIfNeeded(from viewController: UIViewController) {
        guard !authService.isAuthenticated() else { return }
        
        let authVC = AuthenticationViewController()
        authVC.modalPresentationStyle = .fullScreen
        authenticationViewController = authVC
        
        viewController.present(authVC, animated: true)
    }
    
    func authenticateForNoteAccess() async throws -> Bool {
        guard !authService.isAuthenticated() else { return true }
        
        let result = try await authService.authenticateWithProgressiveFallback()
        return result == .success
    }
    
    func logout() async {
        await authService.logout()
    }
}
