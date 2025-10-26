import UIKit
import Foundation

// MARK: - Onboarding Flow System

// MARK: - Onboarding Coordinator

class OnboardingCoordinator: UIViewController {
    
    // MARK: - Properties
    
    private var currentStepIndex = 0
    private let steps: [OnboardingStep]
    private let containerView = UIView()
    private let progressView = UIProgressView()
    
    init(steps: [OnboardingStep]) {
        self.steps = steps
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        showCurrentStep()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Progress view
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        
        // Container view for steps
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        view.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            containerView.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 40),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        updateProgressView()
    }
    
    private func showCurrentStep() {
        guard currentStepIndex < steps.count else {
            completeOnboarding()
            return
        }
        
        let step = steps[currentStepIndex]
        let stepViewController = createStepViewController(for: step)
        
        // Remove previous step
        containerView.subviews.forEach { $0.removeFromSuperview() }
        
        // Add current step
        addChild(stepViewController)
        containerView.addSubview(stepViewController.view)
        stepViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stepViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            stepViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            stepViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            stepViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        stepViewController.didMove(toParent: self)
        
        updateProgressView()
    }
    
    private func createStepViewController(for step: OnboardingStep) -> UIViewController {
        switch step.type {
        case .welcome:
            return WelcomeStepViewController(step: step)
        case .features:
            return FeaturesStepViewController(step: step)
        case .permissions:
            return PermissionsStepViewController(step: step)
        case .setup:
            return SetupStepViewController(step: step)
        case .completion:
            return CompletionStepViewController(step: step)
        }
    }
    
    private func updateProgressView() {
        let progress = Float(currentStepIndex + 1) / Float(steps.count)
        progressView.setProgress(progress, animated: true)
    }
    
    func nextStep() {
        currentStepIndex += 1
        showCurrentStep()
    }
    
    func previousStep() {
        guard currentStepIndex > 0 else { return }
        currentStepIndex -= 1
        showCurrentStep()
    }
    
    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
        dismiss(animated: true)
    }
}

// MARK: - Onboarding Step

struct OnboardingStep {
    let type: StepType
    let title: String
    let description: String
    let imageName: String?
    let actionTitle: String?
    let skipAvailable: Bool
    
    enum StepType {
        case welcome
        case features
        case permissions
        case setup
        case completion
    }
}

// MARK: - Onboarding Step View Controllers

class WelcomeStepViewController: UIViewController {
    
    private let step: OnboardingStep
    
    init(step: OnboardingStep) {
        self.step = step
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .center
        stackView.distribution = .fill
        
        // Icon
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: step.imageName ?? "note.text")
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.heightAnchor.constraint(equalToConstant: 100).isActive = true
        iconView.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = step.title
        titleLabel.font = .systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        // Description
        let descriptionLabel = UILabel()
        descriptionLabel.text = step.description
        descriptionLabel.font = .systemFont(ofSize: 17, weight: .regular)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .secondaryLabel
        
        // Next button
        let nextButton = UIButton(type: .system)
        nextButton.setTitle(step.actionTitle ?? "Get Started", for: .normal)
        nextButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        nextButton.backgroundColor = .systemBlue
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 12
        nextButton.translatesAutoresizingMaskIntoConstraints = false
        nextButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        stackView.addArrangedSubview(iconView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }
}

class FeaturesStepViewController: UIViewController {
    
    private let step: OnboardingStep
    
    init(step: OnboardingStep) {
        self.step = step
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        let contentView = UIStackView()
        contentView.axis = .vertical
        contentView.spacing = 30
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = step.title
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        // Description
        let descriptionLabel = UILabel()
        descriptionLabel.text = step.description
        descriptionLabel.font = .systemFont(ofSize: 17, weight: .regular)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textColor = .secondaryLabel
        
        contentView.addArrangedSubview(titleLabel)
        contentView.addArrangedSubview(descriptionLabel)
        
        // Feature list
        let features = [
            ("Encryption", "Your notes are encrypted with AES-256"),
            ("Cloud Sync", "Sync across all your devices"),
            ("Biometric Security", "Secure with Face ID or Touch ID"),
            ("Multi-Window Support", "Work with multiple notes at once")
        ]
        
        for (title, description) in features {
            let featureView = createFeatureView(title: title, description: description)
            contentView.addArrangedSubview(featureView)
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 40),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -40),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -80)
        ])
    }
    
    private func createFeatureView(title: String, description: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .systemGray6
        containerView.layer.cornerRadius = 12
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .systemFont(ofSize: 15, weight: .regular)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        
        containerView.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16)
        ])
        
        return containerView
    }
}

class PermissionsStepViewController: UIViewController {
    
    private let step: OnboardingStep
    
    init(step: OnboardingStep) {
        self.step = step
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Similar implementation to WelcomeStepViewController
        // But focused on requesting permissions
    }
}

class SetupStepViewController: UIViewController {
    
    private let step: OnboardingStep
    
    init(step: OnboardingStep) {
        self.step = step
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Similar implementation to WelcomeStepViewController
        // But focused on setting up the app
    }
}

class CompletionStepViewController: UIViewController {
    
    private let step: OnboardingStep
    
    init(step: OnboardingStep) {
        self.step = step
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        // Similar implementation to WelcomeStepViewController
        // But focused on completing the onboarding
    }
}

// MARK: - Onboarding Manager

class OnboardingManager {
    
    static let shared = OnboardingManager()
    
    func shouldShowOnboarding() -> Bool {
        return !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
    
    func createOnboardingFlow() -> OnboardingCoordinator {
        let steps = [
            OnboardingStep(
                type: .welcome,
                title: "Welcome to Smart Notes",
                description: "Your secure, intelligent note-taking companion",
                imageName: "note.text",
                actionTitle: "Get Started",
                skipAvailable: false
            ),
            OnboardingStep(
                type: .features,
                title: "Powerful Features",
                description: "Everything you need to stay organized",
                imageName: nil,
                actionTitle: "Continue",
                skipAvailable: false
            ),
            OnboardingStep(
                type: .permissions,
                title: "Enable Permissions",
                description: "Unlock the full potential of Smart Notes",
                imageName: "lock.shield",
                actionTitle: "Enable",
                skipAvailable: true
            ),
            OnboardingStep(
                type: .setup,
                title: "Customize Your Experience",
                description: "Make Smart Notes work exactly how you want",
                imageName: "gearshape",
                actionTitle: "Set Up",
                skipAvailable: true
            ),
            OnboardingStep(
                type: .completion,
                title: "You're All Set!",
                description: "Start creating your first note",
                imageName: "checkmark.circle.fill",
                actionTitle: "Start Using Smart Notes",
                skipAvailable: false
            )
        ]
        
        return OnboardingCoordinator(steps: steps)
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}
