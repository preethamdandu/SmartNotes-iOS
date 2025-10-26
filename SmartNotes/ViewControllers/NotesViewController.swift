import UIKit
import Combine

// MARK: - Notes View Controller

class NotesViewController: UIViewController {
    
    // MARK: - Properties
    
    private let viewModel = NotesViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - UI Components
    
    private lazy var collectionView: UICollectionView = {
        let layout = createCollectionViewLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(NoteCell.self, forCellWithReuseIdentifier: NoteCell.identifier)
        collectionView.register(NoteHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: NoteHeaderView.identifier)
        
        // Enable scrolling
        collectionView.isScrollEnabled = true
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        
        return collectionView
    }()
    
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search notes..."
        searchController.searchBar.delegate = self
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.enablesReturnKeyAutomatically = true
        return searchController
    }()
    
    private lazy var addButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addButtonTapped)
        )
        return button
    }()
    
    private lazy var syncButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(syncButtonTapped)
        )
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        loadNotes()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Notes"
        view.backgroundColor = .systemGroupedBackground
        
        // Navigation bar
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.rightBarButtonItems = [addButton, syncButton]
        
        // Collection view
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupBindings() {
        viewModel.$filteredNotes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
                // Scroll to top when notes change
                if let self = self, !self.viewModel.filteredNotes.isEmpty {
                    self.collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .top, animated: true)
                }
            }
            .store(in: &cancellables)
        
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.syncButton.isEnabled = !isLoading
                if isLoading {
                    self?.syncButton.title = "Syncing..."
                } else {
                    self?.syncButton.title = "Sync"
                }
            }
            .store(in: &cancellables)
        
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if let errorMessage = errorMessage {
                    self?.showError(errorMessage)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    @objc private func addButtonTapped() {
        let addNoteVC = AddNoteViewController()
        addNoteVC.delegate = self
        let navController = UINavigationController(rootViewController: addNoteVC)
        present(navController, animated: true)
    }
    
    @objc private func syncButtonTapped() {
        Task {
            do {
                try await viewModel.syncNotes()
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func loadNotes() {
        Task {
            do {
                try await viewModel.loadNotes()
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Layout
    
    private func createCollectionViewLayout() -> UICollectionViewLayout {
        // Use UICollectionViewFlowLayout for better scrolling support
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 12
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        layout.headerReferenceSize = CGSize(width: 0, height: 60)
        
        // Use estimated size for dynamic height
        layout.estimatedItemSize = CGSize(width: UIScreen.main.bounds.width - 32, height: 120)
        
        return layout
    }
}

// MARK: - UICollectionViewDataSource

extension NotesViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.filteredNotes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NoteCell.identifier, for: indexPath) as! NoteCell
        let note = viewModel.filteredNotes[indexPath.item]
        cell.configure(with: note)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: NoteHeaderView.identifier, for: indexPath) as! NoteHeaderView
        headerView.configure(title: "All Notes", count: viewModel.filteredNotes.count)
        return headerView
    }
}

// MARK: - UICollectionViewDelegate

extension NotesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let note = viewModel.filteredNotes[indexPath.item]
        let detailVC = NoteDetailViewController(note: note)
        detailVC.delegate = self
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - UISearchResultsUpdating

extension NotesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
    }
}

// MARK: - UISearchBarDelegate

extension NotesViewController: UISearchBarDelegate {
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // Ensure cursor appears and search is active
        searchBar.becomeFirstResponder()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        viewModel.searchText = ""
        searchBar.resignFirstResponder()
    }
}

// MARK: - AddNoteDelegate

extension NotesViewController: AddNoteDelegate {
    func didAddNote(_ note: Note) {
        Task {
            do {
                try await viewModel.saveNote(note)
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
}

// MARK: - NoteDetailDelegate

extension NotesViewController: NoteDetailDelegate {
    func didUpdateNote(_ note: Note) {
        Task {
            do {
                try await viewModel.updateNote(note)
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
    
    func didDeleteNote(_ note: Note) {
        Task {
            do {
                try await viewModel.deleteNote(note)
            } catch {
                await MainActor.run {
                    self.showError(error.localizedDescription)
                }
            }
        }
    }
}