import UIKit
import SwiftUI

// MARK: - Modular Component Design Architecture

// MARK: - Component Protocol

protocol UIComponent {
    associatedtype Configuration
    associatedtype State
    
    func configure(with configuration: Configuration)
    func updateState(_ state: State)
    func reset()
}

// MARK: - Component Factory

protocol ComponentFactory {
    associatedtype ComponentType
    
    func createComponent() -> ComponentType
    func configureComponent(_ component: ComponentType, with configuration: ComponentFactory.Configuration?)
}

class SmartNotesComponentFactory: ComponentFactory {
    
    enum ComponentType {
        case button(ButtonStyle)
        case card(CardStyle)
        case list(ListStyle)
        case header(HeaderStyle)
        case empty(EmptyStateStyle)
        
        enum ButtonStyle {
            case primary
            case secondary
            case destructive
            case icon
        }
        
        enum CardStyle {
            case note
            case folder
            case searchResult
        }
        
        enum ListStyle {
            case notes
            case folders
            case searchResults
        }
        
        enum HeaderStyle {
            case section
            case navigation
            case search
        }
        
        enum EmptyStateStyle {
            case noNotes
            case noSearchResults
            case noFolders
            case loading
        }
    }
    
    func createComponent<T: UIView>(type: ComponentType) -> T {
        switch type {
        case .button(let style):
            return createButton(style: style) as! T
        case .card(let style):
            return createCard(style: style) as! T
        case .list(let style):
            return createList(style: style) as! T
        case .header(let style):
            return createHeader(style: style) as! T
        case .empty(let style):
            return createEmptyState(style: style) as! T
        }
    }
    
    private func createButton(style: ComponentType.ButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        
        switch style {
        case .primary:
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
        case .secondary:
            button.backgroundColor = .systemGray
            button.setTitleColor(.white, for: .normal)
        case .destructive:
            button.backgroundColor = .systemRed
            button.setTitleColor(.white, for: .normal)
        case .icon:
            button.backgroundColor = .clear
            button.tintColor = .systemBlue
        }
        
        return button
    }
    
    private func createCard(style: ComponentType.CardStyle) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = .systemBackground
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.1
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 4
        
        return cardView
    }
    
    private func createList(style: ComponentType.ListStyle) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 8
        layout.minimumInteritemSpacing = 8
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemGroupedBackground
        
        return collectionView
    }
    
    private func createHeader(style: ComponentType.HeaderStyle) -> UIView {
        let headerView = UIView()
        headerView.backgroundColor = .systemBackground
        
        return headerView
    }
    
    private func createEmptyState(style: ComponentType.EmptyStateStyle) -> UIView {
        let emptyStateView = UIView()
        emptyStateView.backgroundColor = .clear
        
        let iconView = UIImageView()
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = .systemGray
        
        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = .label
        
        let messageLabel = UILabel()
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        
        emptyStateView.addSubview(iconView)
        emptyStateView.addSubview(titleLabel)
        emptyStateView.addSubview(messageLabel)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: emptyStateView.topAnchor, constant: 40),
            iconView.widthAnchor.constraint(equalToConstant: 80),
            iconView.heightAnchor.constraint(equalToConstant: 80),
            
            titleLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -20),
            
            messageLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor, constant: -20)
        ])
        
        switch style {
        case .noNotes:
            iconView.image = UIImage(systemName: "note.text")
            titleLabel.text = "No Notes"
            messageLabel.text = "Tap the + button to create your first note"
        case .noSearchResults:
            iconView.image = UIImage(systemName: "magnifyingglass")
            titleLabel.text = "No Results"
            messageLabel.text = "Try a different search term"
        case .noFolders:
            iconView.image = UIImage(systemName: "folder")
            titleLabel.text = "No Folders"
            messageLabel.text = "Create folders to organize your notes"
        case .loading:
            iconView.image = UIImage(systemName: "arrow.clockwise")
            titleLabel.text = "Loading..."
            messageLabel.text = "Please wait"
        }
        
        return emptyStateView
    }
    
    func configureComponent(_ component: Any, with configuration: ComponentFactory.Configuration?) {
        // Configure component with configuration
    }
}

// MARK: - Component Configuration

struct ComponentConfiguration {
    let style: ComponentStyle
    let theme: ComponentTheme
    let accessibility: AccessibilityConfiguration
    
    enum ComponentStyle {
        case compact
        case standard
        case extended
    }
    
    enum ComponentTheme {
        case light
        case dark
        case auto
    }
    
    struct AccessibilityConfiguration {
        let label: String?
        let hint: String?
        let traits: UIAccessibilityTraits
    }
}

// MARK: - Component Builder Pattern

class ComponentBuilder {
    private var configuration = ComponentConfiguration(
        style: .standard,
        theme: .auto,
        accessibility: ComponentConfiguration.AccessibilityConfiguration(
            label: nil,
            hint: nil,
            traits: []
        )
    )
    
    func withStyle(_ style: ComponentConfiguration.ComponentStyle) -> Self {
        configuration = ComponentConfiguration(
            style: style,
            theme: configuration.theme,
            accessibility: configuration.accessibility
        )
        return self
    }
    
    func withTheme(_ theme: ComponentConfiguration.ComponentTheme) -> Self {
        configuration = ComponentConfiguration(
            style: configuration.style,
            theme: theme,
            accessibility: configuration.accessibility
        )
        return self
    }
    
    func withAccessibility(_ accessibility: ComponentConfiguration.AccessibilityConfiguration) -> Self {
        configuration = ComponentConfiguration(
            style: configuration.style,
            theme: configuration.theme,
            accessibility: accessibility
        )
        return self
    }
    
    func build() -> ComponentConfiguration {
        return configuration
    }
}

// MARK: - Component Registry

class ComponentRegistry {
    static let shared = ComponentRegistry()
    
    private var registeredComponents: [String: UIComponent] = [:]
    
    func register<T: UIComponent>(_ component: T, forKey key: String) {
        registeredComponents[key] = component
    }
    
    func component<T: UIComponent>(forKey key: String) -> T? {
        return registeredComponents[key] as? T
    }
    
    func unregister(forKey key: String) {
        registeredComponents.removeValue(forKey: key)
    }
}
