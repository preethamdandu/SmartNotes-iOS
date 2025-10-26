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
        
        // Search tab - Use the full implementation from SearchAndSettingsViewController
        let searchVC = SearchViewController()
        let searchNavController = UINavigationController(rootViewController: searchVC)
        searchNavController.tabBarItem = UITabBarItem(
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass.circle.fill")
        )
        
        // Settings tab
        let settingsVC = SettingsViewController()
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


