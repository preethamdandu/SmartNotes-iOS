import UIKit

// MARK: - Main Tab Bar Controller

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
    }
    
    private func setupTabBar() {
        // Notes tab
        let notesVC = NotesViewController()
        let notesNavController = UINavigationController(rootViewController: notesVC)
        notesNavController.tabBarItem = UITabBarItem(
            title: "Notes",
            image: UIImage(systemName: "note.text"),
            selectedImage: UIImage(systemName: "note.text.fill")
        )
        
        // Search tab - Create a simple working version
        let searchVC = SimpleSearchViewController()
        let searchNavController = UINavigationController(rootViewController: searchVC)
        searchNavController.tabBarItem = UITabBarItem(
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass.circle.fill")
        )
        
        // Settings tab - Create a simple working version
        let settingsVC = SimpleSettingsViewController()
        let settingsNavController = UINavigationController(rootViewController: settingsVC)
        settingsNavController.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gear"),
            selectedImage: UIImage(systemName: "gear.fill")
        )
        
        viewControllers = [notesNavController, searchNavController, settingsNavController]
        
        // Configure tab bar appearance
        tabBar.tintColor = .systemBlue
        tabBar.backgroundColor = .systemBackground
    }
}

// MARK: - Simple Search View Controller

class SimpleSearchViewController: UIViewController {
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView()
    private var searchResults: [Note] = []
    private var allNotes: [Note] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadSampleNotes()
        setupUI()
    }
    
    private func loadSampleNotes() {
        allNotes = [
            Note(title: "Welcome to Smart Notes", content: "This is your first note. Start organizing your thoughts!", tags: ["welcome", "getting-started"], color: .blue, isPinned: true),
            Note(title: "Meeting Notes", content: "Discuss project timeline and deliverables for Q1.", tags: ["work", "meeting"], color: .green),
            Note(title: "Shopping List", content: "Milk, eggs, bread, apples", tags: ["personal", "shopping"], color: .yellow),
            Note(title: "Ideas", content: "New app feature ideas and improvements", tags: ["ideas", "development"], color: .purple),
            Note(title: "Class tomorrow", content: "Remember to bring laptop and charger for iOS development class", tags: ["education", "reminder"], color: .orange),
            Note(title: "Project Deadline", content: "Submit final project by Friday. Need to complete testing and documentation.", tags: ["work", "deadline"], color: .red),
            Note(title: "Grocery Store", content: "Buy ingredients for dinner: pasta, tomatoes, cheese, herbs", tags: ["personal", "cooking"], color: .green),
            Note(title: "Book Recommendations", content: "Clean Code by Robert Martin, Design Patterns by Gang of Four", tags: ["reading", "programming"], color: .blue),
            Note(title: "Weekend Plans", content: "Visit the museum, have dinner with friends, relax at home", tags: ["personal", "weekend"], color: .purple),
            Note(title: "Learning Goals", content: "Master SwiftUI, learn about Core Data, practice algorithms", tags: ["learning", "goals"], color: .yellow)
        ]
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
    
    private func performSearch(query: String) {
        print("🔍 Search query: '\(query)'")
        print("📝 Total notes available: \(allNotes.count)")
        
        guard !query.isEmpty else {
            searchResults = []
            tableView.reloadData()
            return
        }
        
        // Search in sample notes
        searchResults = allNotes.filter { note in
            let titleMatch = note.title.localizedCaseInsensitiveContains(query)
            let contentMatch = note.content.localizedCaseInsensitiveContains(query)
            let tagMatch = note.tags.contains { $0.localizedCaseInsensitiveContains(query) }
            
            if titleMatch || contentMatch || tagMatch {
                print("✅ Found match: '\(note.title)' - Title: \(titleMatch), Content: \(contentMatch), Tag: \(tagMatch)")
            }
            
            return titleMatch || contentMatch || tagMatch
        }
        
        print("🎯 Search results count: \(searchResults.count)")
        tableView.reloadData()
    }
}

extension SimpleSearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        print("🔄 Search results updating with query: '\(query)'")
        performSearch(query: query)
    }
}

extension SimpleSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let note = searchResults[indexPath.row]
        cell.textLabel?.text = note.title
        cell.detailTextLabel?.text = note.content
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let note = searchResults[indexPath.row]
        let alert = UIAlertController(title: note.title, message: note.content, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Simple Settings View Controller

class SimpleSettingsViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .grouped)
    
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

extension SimpleSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2 // General
        case 1: return 2 // Security
        case 2: return 1 // About
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "General"
        case 1: return "Security"
        case 2: return "About"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Sync Settings"
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.textLabel?.text = "Notifications"
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
        case 1:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Face ID / Touch ID"
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.textLabel?.text = "Encryption"
                cell.accessoryType = .disclosureIndicator
            default:
                break
            }
        case 2:
            cell.textLabel?.text = "About Smart Notes"
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let alert = UIAlertController(title: "Feature", message: "This feature will be implemented", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
