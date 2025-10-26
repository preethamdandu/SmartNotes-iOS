import UIKit

// MARK: - Search View Controller

class SearchViewController: UIViewController {
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private var searchResults: [Note] = []
    private let noteService: NoteServiceProtocol = NoteService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "Search"
        view.backgroundColor = .systemGroupedBackground
        
        // Search controller setup
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search notes..."
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Table view setup
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            tableView.reloadData()
            return
        }
        
        Task {
            do {
                let results = try await noteService.searchNotes(query: query)
                await MainActor.run {
                    self.searchResults = results
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.showErrorAlert(message: "Search failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Search Results Updating

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        performSearch(query: query)
    }
}

// MARK: - Table View Data Source & Delegate

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.identifier, for: indexPath) as! SearchResultCell
        let note = searchResults[indexPath.row]
        cell.configure(with: note)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let note = searchResults[indexPath.row]
        let detailVC = NoteDetailViewController(note: note)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Search Result Cell

class SearchResultCell: UITableViewCell {
    static let identifier = "SearchResultCell"
    
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let dateLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Title label
        titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 1
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Content label
        contentLabel.font = UIFont.preferredFont(forTextStyle: .body)
        contentLabel.textColor = .secondaryLabel
        contentLabel.numberOfLines = 2
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentLabel)
        
        // Date label
        dateLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        dateLabel.textColor = .tertiaryLabel
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            dateLabel.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            dateLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            dateLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with note: Note) {
        titleLabel.text = note.title
        contentLabel.text = note.content
        dateLabel.text = formatDate(note.updatedAt)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Settings View Controller

class SettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let authService: AuthenticationServiceProtocol = AuthenticationService()
    
    private enum SettingsSection: Int, CaseIterable {
        case security = 0
        case sync = 1
        case appearance = 2
        case about = 3
        
        var title: String {
            switch self {
            case .security: return "Security"
            case .sync: return "Sync"
            case .appearance: return "Appearance"
            case .about: return "About"
            }
        }
    }
    
    private enum SecurityRow: Int, CaseIterable {
        case biometrics = 0
        case encryption = 1
        
        var title: String {
            switch self {
            case .biometrics: return "Biometric Authentication"
            case .encryption: return "Note Encryption"
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        
        tableView.delegate = self
        tableView.dataSource = self
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

// MARK: - Table View Data Source & Delegate

extension SettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settingsSection = SettingsSection(rawValue: section) else { return 0 }
        
        switch settingsSection {
        case .security: return SecurityRow.allCases.count
        case .sync: return 2
        case .appearance: return 1
        case .about: return 1
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let settingsSection = SettingsSection(rawValue: section) else { return nil }
        return settingsSection.title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        guard let settingsSection = SettingsSection(rawValue: indexPath.section) else {
            return cell
        }
        
        switch settingsSection {
        case .security:
            guard let securityRow = SecurityRow(rawValue: indexPath.row) else { return cell }
            cell.textLabel?.text = securityRow.title
            cell.accessoryType = .disclosureIndicator
            
        case .sync:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Sync Now"
                cell.accessoryType = .none
            case 1:
                cell.textLabel?.text = "Auto Sync"
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
            
        case .appearance:
            cell.textLabel?.text = "Theme"
            cell.accessoryType = .disclosureIndicator
            
        case .about:
            cell.textLabel?.text = "About Smart Notes"
            cell.accessoryType = .disclosureIndicator
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let settingsSection = SettingsSection(rawValue: indexPath.section) else { return }
        
        switch settingsSection {
        case .security:
            handleSecurityRowTap(at: indexPath.row)
            
        case .sync:
            handleSyncRowTap(at: indexPath.row)
            
        case .appearance:
            showThemeSettings()
            
        case .about:
            showAbout()
        }
    }
    
    private func handleSecurityRowTap(at row: Int) {
        guard let securityRow = SecurityRow(rawValue: row) else { return }
        
        switch securityRow {
        case .biometrics:
            Task {
                do {
                    try await authService.authenticateWithBiometrics()
                    await MainActor.run {
                        self.showAlert(title: "Success", message: "Biometric authentication enabled")
                    }
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "Error", message: error.localizedDescription)
                    }
                }
            }
            
        case .encryption:
            showAlert(title: "Encryption", message: "All notes are encrypted using AES-256 encryption")
        }
    }
    
    private func handleSyncRowTap(at row: Int) {
        switch row {
        case 0:
            // Sync now
            let syncService = SyncService()
            Task {
                do {
                    try await syncService.syncNotes()
                    await MainActor.run {
                        self.showAlert(title: "Success", message: "Sync completed")
                    }
                } catch {
                    await MainActor.run {
                        self.showAlert(title: "Error", message: error.localizedDescription)
                    }
                }
            }
            
        case 1:
            // Auto sync settings
            showAlert(title: "Auto Sync", message: "Auto sync settings coming soon")
            
        default:
            break
        }
    }
    
    private func showThemeSettings() {
        let alert = UIAlertController(title: "Theme", message: "Choose your preferred theme", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "System", style: .default) { _ in
            // Handle system theme
        })
        
        alert.addAction(UIAlertAction(title: "Light", style: .default) { _ in
            // Handle light theme
        })
        
        alert.addAction(UIAlertAction(title: "Dark", style: .default) { _ in
            // Handle dark theme
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func showAbout() {
        let alert = UIAlertController(
            title: "Smart Notes",
            message: "Version 1.0\n\nA secure, cross-device note-taking app built with UIKit and Swift.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
