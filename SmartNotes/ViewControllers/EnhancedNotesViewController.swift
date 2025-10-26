import UIKit
import Combine
import os.log

// MARK: - Enhanced Notes View Controller with Drag and Drop

class EnhancedNotesViewController: UIViewController {
    
    // MARK: - Properties
    
    private let viewModel = NotesViewModel()
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.apple.smartnotes", category: "notes.controller")
    
    // Drag and drop
    private var dragDropManager: AdvancedDragDropManager?
    
    // Device-specific properties
    private let deviceIdiom = UIDevice.current.userInterfaceIdiom
    private let isIPad = UIDevice.current.userInterfaceIdiom == .pad
    
    // UI Components
    private lazy var collectionView: UICollectionView = {
        let layout = createCollectionViewLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(NoteCell.self, forCellWithReuseIdentifier: NoteCell.identifier)
        collectionView.register(NoteHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: NoteHeaderView.identifier)
        
        // Configure for drag and drop
        collectionView.dragInteractionEnabled = true
        collectionView.reorderingCadence = isIPad ? .immediate : .slow
        
        return collectionView
    }()
    
    private lazy var searchController: UISearchController = {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search notes..."
        return searchController
    }()
    
    private lazy var addButton: UIBarButtonItem = {
        return UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addNoteTapped)
        )
    }()
    
    private lazy var syncButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(syncTapped)
        )
        return button
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupDragAndDrop()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureForCurrentDevice()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateLayoutForCurrentOrientation()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        title = "Smart Notes"
        view.backgroundColor = .systemGroupedBackground
        
        // Navigation bar setup
        navigationItem.searchController = searchController
        navigationItem.rightBarButtonItems = [addButton, syncButton]
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Collection view setup
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Configure for device type
        configureForCurrentDevice()
    }
    
    private func setupBindings() {
        // Bind view model to UI
        viewModel.$filteredNotes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
        
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.updateLoadingState(isLoading)
            }
            .store(in: &cancellables)
        
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                if let errorMessage = errorMessage {
                    self?.showErrorAlert(message: errorMessage)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupDragAndDrop() {
        // Initialize drag and drop manager
        dragDropManager = AdvancedDragDropManager(collectionView: collectionView, viewController: self)
        
        // Configure drag preview provider
        dragDropManager?.setDragPreviewProvider(self)
        
        // Configure drop proposal provider
        dragDropManager?.setDropProposalProvider(self)
        
        // Add long press gesture for iPhone
        if !isIPad {
            dragDropManager?.addLongPressGestureRecognizer()
        }
        
        logger.info("Drag and drop setup completed for \(isIPad ? "iPad" : "iPhone")")
    }
    
    // MARK: - Device Configuration
    
    private func configureForCurrentDevice() {
        if isIPad {
            configureForiPad()
        } else {
            configureForiPhone()
        }
    }
    
    private func configureForiPad() {
        // iPad-specific configuration
        navigationController?.navigationBar.prefersLargeTitles = true
        
        // Configure for multi-window support
        dragDropManager?.configureForMultiWindow()
        dragDropManager?.configureForSplitView()
        
        // Enable full drag and drop capabilities
        collectionView.dragInteractionEnabled = true
        collectionView.reorderingCadence = .immediate
        
        logger.info("Configured for iPad with full drag and drop capabilities")
    }
    
    private func configureForiPhone() {
        // iPhone-specific configuration
        navigationController?.navigationBar.prefersLargeTitles = false
        
        // Configure for compact layout
        dragDropManager?.configureForCompactLayout()
        dragDropManager?.configureForOneHandedUse()
        
        // Enable limited drag and drop capabilities
        collectionView.dragInteractionEnabled = true
        collectionView.reorderingCadence = .slow
        
        logger.info("Configured for iPhone with limited drag and drop capabilities")
    }
    
    private func updateLayoutForCurrentOrientation() {
        // Update layout based on current orientation
        let orientation = UIDevice.current.orientation
        
        if isIPad {
            updateiPadLayoutForOrientation(orientation)
        } else {
            updateiPhoneLayoutForOrientation(orientation)
        }
    }
    
    private func updateiPadLayoutForOrientation(_ orientation: UIDeviceOrientation) {
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            // Landscape iPad - optimize for wider layout
            collectionView.collectionViewLayout.invalidateLayout()
        case .portrait, .portraitUpsideDown:
            // Portrait iPad - optimize for taller layout
            collectionView.collectionViewLayout.invalidateLayout()
        default:
            break
        }
    }
    
    private func updateiPhoneLayoutForOrientation(_ orientation: UIDeviceOrientation) {
        // iPhone layout updates are typically handled automatically
        // but we can add specific optimizations here if needed
    }
    
    // MARK: - Layout Creation
    
    private func createCollectionViewLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            if self.isIPad {
                return self.createiPadSection(layoutEnvironment: layoutEnvironment)
            } else {
                return self.createiPhoneSection()
            }
        }
        
        return layout
    }
    
    private func createiPadSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        // iPad: Multi-column layout with drag and drop support
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5), // 2 columns
            heightDimension: .estimated(120)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(120)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        section.interGroupSpacing = 16
        
        // Add header
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    private func createiPhoneSection() -> NSCollectionLayoutSection {
        // iPhone: Single-column layout optimized for touch
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        section.interGroupSpacing = 8
        
        // Add header
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(44)
        )
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        section.boundarySupplementaryItems = [header]
        
        return section
    }
    
    // MARK: - Actions
    
    @objc private func addNoteTapped() {
        let addNoteVC = AddNoteViewController()
        addNoteVC.delegate = self
        let navController = UINavigationController(rootViewController: addNoteVC)
        present(navController, animated: true)
    }
    
    @objc private func syncTapped() {
        viewModel.syncNotes()
    }
    
    // MARK: - Helper Methods
    
    private func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            // Show loading indicator
            let activityIndicator = UIActivityIndicatorView(style: .medium)
            activityIndicator.startAnimating()
            navigationItem.rightBarButtonItems = [addButton, UIBarButtonItem(customView: activityIndicator)]
        } else {
            // Show sync button
            navigationItem.rightBarButtonItems = [addButton, syncButton]
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Drag and Drop Helpers
    
    private func handleReorder(from sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        logger.debug("Handling reorder from \(sourceIndexPath) to \(destinationIndexPath)")
        
        // Update the view model
        viewModel.reorderNote(from: sourceIndexPath.item, to: destinationIndexPath.item)
        
        // Provide haptic feedback
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator.impactOccurred()
    }
    
    private func handleExternalDrop(_ content: Any, at indexPath: IndexPath) {
        logger.debug("Handling external drop at \(indexPath)")
        
        // Handle different types of dropped content
        if let text = content as? String {
            // Create a new note from dropped text
            viewModel.createNote(title: "Dropped Note", content: text, tags: [], color: .default)
        }
        
        // Provide haptic feedback
        let feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator.notificationOccurred(.success)
    }
}

// MARK: - Collection View Data Source & Delegate

extension EnhancedNotesViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.filteredNotes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NoteCell.identifier, for: indexPath) as! NoteCell
        let note = viewModel.filteredNotes[indexPath.item]
        cell.configure(with: note)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let note = viewModel.filteredNotes[indexPath.item]
        let detailVC = NoteDetailViewController(note: note)
        detailVC.delegate = self
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: NoteHeaderView.identifier, for: indexPath) as! NoteHeaderView
        header.configure(title: "All Notes", count: viewModel.filteredNotes.count)
        return header
    }
    
    // MARK: - Reordering Support
    
    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        handleReorder(from: sourceIndexPath, to: destinationIndexPath)
    }
}

// MARK: - Search Results Updating

extension EnhancedNotesViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
    }
}

// MARK: - Drag Preview Provider

extension EnhancedNotesViewController: DragPreviewProvider {
    func createDragPreview(for item: UIDragItem) -> UIDragPreview? {
        guard let indexPath = item.localObject as? IndexPath,
              let cell = collectionView.cellForItem(at: indexPath) else {
            return nil
        }
        
        // Create a custom drag preview
        let snapshot = cell.snapshotView(afterScreenUpdates: false)
        snapshot?.frame = cell.frame
        
        let preview = UIDragPreview(view: snapshot ?? cell)
        preview.parameters = UIDragPreviewParameters()
        preview.parameters.backgroundColor = .clear
        
        // Add shadow for better visual feedback
        if let cell = collectionView.cellForItem(at: indexPath) {
            preview.parameters.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 12)
        }
        
        return preview
    }
}

// MARK: - Drop Proposal Provider

extension EnhancedNotesViewController: DropProposalProvider {
    func createDropProposal(for session: UIDropSession) -> UICollectionViewDropProposal {
        let operation: UIDropOperation
        
        if session.localDragSession != nil {
            // Local drag - allow reordering
            operation = .move
        } else {
            // External drag - allow copy
            operation = .copy
        }
        
        return UICollectionViewDropProposal(operation: operation, intent: .insertAtDestinationIndexPath)
    }
}

// MARK: - Delegate Extensions

extension EnhancedNotesViewController: AddNoteDelegate {
    func didAddNote(_ note: Note) {
        viewModel.createNote(title: note.title, content: note.content, tags: note.tags, color: note.color)
    }
}

extension EnhancedNotesViewController: NoteDetailDelegate {
    func didUpdateNote(_ note: Note) {
        viewModel.updateNote(note)
    }
    
    func didDeleteNote(_ note: Note) {
        viewModel.deleteNote(note)
    }
}
