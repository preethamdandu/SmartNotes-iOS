import Foundation
import CoreData
import Combine
import os.log

// MARK: - Optimized Data Service with Lazy Loading

class OptimizedDataService {
    private let logger = Logger(subsystem: "com.apple.smartnotes", category: "data.service")
    private let coreDataStack = CoreDataStack.shared
    private let memoryManager = LazyLoadingMemoryManager()
    
    // Pagination configuration
    private let pageSize = 20
    private let prefetchThreshold = 5
    private let maxCachedPages = 10
    
    // State management
    private var currentPage = 0
    private var totalCount = 0
    private var isLoading = false
    private var hasMoreData = true
    
    // Caching
    private var cachedPages: [Int: [Note]] = [:]
    private var cacheTimestamps: [Int: Date] = [:]
    private let cacheExpirationTime: TimeInterval = 300 // 5 minutes
    
    // Publishers
    private let notesSubject = CurrentValueSubject<[Note], Never>([])
    private let loadingSubject = CurrentValueSubject<Bool, Never>(false)
    private let errorSubject = PassthroughSubject<Error, Never>()
    
    var notesPublisher: AnyPublisher<[Note], Never> {
        notesSubject.eraseToAnyPublisher()
    }
    
    var loadingPublisher: AnyPublisher<Bool, Never> {
        loadingSubject.eraseToAnyPublisher()
    }
    
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    
    init() {
        setupMemoryMonitoring()
        loadInitialData()
    }
    
    private func setupMemoryMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() {
        guard !isLoading else { return }
        
        isLoading = true
        loadingSubject.send(true)
        
        Task {
            do {
                let totalCount = try await getTotalNoteCount()
                self.totalCount = totalCount
                
                let initialNotes = try await loadPage(0)
                await MainActor.run {
                    self.notesSubject.send(initialNotes)
                    self.loadingSubject.send(false)
                    self.isLoading = false
                }
                
                logger.info("Initial data loaded: \(initialNotes.count) notes")
            } catch {
                await MainActor.run {
                    self.errorSubject.send(error)
                    self.loadingSubject.send(false)
                    self.isLoading = false
                }
                
                logger.error("Failed to load initial data: \(error.localizedDescription)")
            }
        }
    }
    
    func loadNextPage() {
        guard !isLoading && hasMoreData else { return }
        
        isLoading = true
        loadingSubject.send(true)
        
        Task {
            do {
                let nextPage = currentPage + 1
                let notes = try await loadPage(nextPage)
                
                await MainActor.run {
                    var currentNotes = self.notesSubject.value
                    currentNotes.append(contentsOf: notes)
                    self.notesSubject.send(currentNotes)
                    
                    self.currentPage = nextPage
                    self.hasMoreData = notes.count == self.pageSize
                    self.loadingSubject.send(false)
                    self.isLoading = false
                }
                
                logger.info("Page \(nextPage) loaded: \(notes.count) notes")
            } catch {
                await MainActor.run {
                    self.errorSubject.send(error)
                    self.loadingSubject.send(false)
                    self.isLoading = false
                }
                
                logger.error("Failed to load page \(currentPage + 1): \(error.localizedDescription)")
            }
        }
    }
    
    func refreshData() {
        // Clear cache and reload
        cachedPages.removeAll()
        cacheTimestamps.removeAll()
        currentPage = 0
        hasMoreData = true
        
        loadInitialData()
    }
    
    // MARK: - Page Loading
    
    private func loadPage(_ page: Int) async throws -> [Note] {
        // Check cache first
        if let cachedNotes = getCachedPage(page) {
            logger.debug("Returning cached page \(page)")
            return cachedNotes
        }
        
        // Load from Core Data
        let notes = try await fetchNotesFromDatabase(page: page)
        
        // Cache the results
        cachePage(page, notes: notes)
        
        return notes
    }
    
    private func fetchNotesFromDatabase(page: Int) async throws -> [Note] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    request.fetchOffset = page * self.pageSize
                    request.fetchLimit = self.pageSize
                    request.fetchBatchSize = self.pageSize
                    
                    // Optimize the request
                    request.returnsObjectsAsFaults = false
                    request.relationshipKeyPathsForPrefetching = ["tags"]
                    
                    request.sortDescriptors = [
                        NSSortDescriptor(keyPath: \NoteEntity.isPinned, ascending: false),
                        NSSortDescriptor(keyPath: \NoteEntity.updatedAt, ascending: false)
                    ]
                    
                    let entities = try context.fetch(request)
                    let notes = entities.compactMap { entity -> Note? in
                        return self.convertEntityToNote(entity)
                    }
                    
                    continuation.resume(returning: notes)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func getTotalNoteCount() async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    request.resultType = .countResultType
                    
                    let count = try context.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Caching
    
    private func getCachedPage(_ page: Int) -> [Note]? {
        guard let timestamp = cacheTimestamps[page] else { return nil }
        
        // Check if cache is expired
        if Date().timeIntervalSince(timestamp) > cacheExpirationTime {
            cachedPages.removeValue(forKey: page)
            cacheTimestamps.removeValue(forKey: page)
            return nil
        }
        
        return cachedPages[page]
    }
    
    private func cachePage(_ page: Int, notes: [Note]) {
        cachedPages[page] = notes
        cacheTimestamps[page] = Date()
        
        // Limit cache size
        if cachedPages.count > maxCachedPages {
            let oldestPage = cacheTimestamps.min { $0.value < $1.value }?.key
            if let oldestPage = oldestPage {
                cachedPages.removeValue(forKey: oldestPage)
                cacheTimestamps.removeValue(forKey: oldestPage)
            }
        }
        
        logger.debug("Cached page \(page) with \(notes.count) notes")
    }
    
    // MARK: - Prefetching
    
    func prefetchIfNeeded(currentIndex: Int) {
        let currentPageIndex = currentIndex / pageSize
        let itemsInCurrentPage = currentIndex % pageSize
        
        // Prefetch if we're close to the end of the current page
        if itemsInCurrentPage >= pageSize - prefetchThreshold {
            loadNextPage()
        }
    }
    
    // MARK: - Memory Management
    
    @objc private func handleMemoryWarning() {
        logger.warning("Memory warning received - clearing caches")
        
        // Clear all caches
        cachedPages.removeAll()
        cacheTimestamps.removeAll()
        
        // Clear memory manager caches
        memoryManager.clearAllCaches()
        
        // Keep only current page in memory
        if currentPage > 0 {
            let currentPageNotes = Array(notesSubject.value.prefix(pageSize))
            notesSubject.send(currentPageNotes)
            currentPage = 0
        }
    }
    
    // MARK: - Data Conversion
    
    private func convertEntityToNote(_ entity: NoteEntity) -> Note? {
        var note = Note(
            title: entity.title ?? "",
            content: entity.content ?? "",
            tags: entity.tags ?? [],
            color: entity.color
        )
        
        note.id = entity.id ?? UUID()
        note.createdAt = entity.createdAt ?? Date()
        note.updatedAt = entity.updatedAt ?? Date()
        note.isEncrypted = entity.isEncrypted
        note.isPinned = entity.isPinned
        
        return note
    }
    
    // MARK: - Public Interface
    
    func getNote(at index: Int) -> Note? {
        let notes = notesSubject.value
        return index < notes.count ? notes[index] : nil
    }
    
    func getTotalCount() -> Int {
        return totalCount
    }
    
    func hasMoreDataToLoad() -> Bool {
        return hasMoreData
    }
    
    func isCurrentlyLoading() -> Bool {
        return isLoading
    }
}

// MARK: - Optimized Notes View Controller

class OptimizedNotesViewController: UIViewController {
    
    // MARK: - Properties
    
    private let dataService = OptimizedDataService()
    private var cancellables = Set<AnyCancellable>()
    
    // UI Components
    private lazy var collectionView: AdvancedLazyLoadingCollectionView = {
        let layout = createCollectionViewLayout()
        let collectionView = AdvancedLazyLoadingCollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .systemGroupedBackground
        collectionView.register(OptimizedNoteCell.self, forCellWithReuseIdentifier: OptimizedNoteCell.identifier)
        return collectionView
    }()
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private lazy var refreshControl: UIRefreshControl = {
        let control = UIRefreshControl()
        control.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        return control
    }()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemGroupedBackground
        
        // Add collection view
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add loading indicator
        view.addSubview(loadingIndicator)
        
        // Add refresh control
        collectionView.refreshControl = refreshControl
        
        // Setup constraints
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Setup navigation
        title = "Smart Notes"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(addNoteTapped)
        )
    }
    
    private func setupBindings() {
        // Bind notes data
        dataService.notesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notes in
                self?.collectionView.reloadData()
            }
            .store(in: &cancellables)
        
        // Bind loading state
        dataService.loadingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                if isLoading {
                    self?.loadingIndicator.startAnimating()
                } else {
                    self?.loadingIndicator.stopAnimating()
                    self?.refreshControl.endRefreshing()
                }
            }
            .store(in: &cancellables)
        
        // Bind errors
        dataService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showErrorAlert(message: error.localizedDescription)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Layout
    
    private func createCollectionViewLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, layoutEnvironment in
            let deviceIdiom = UIDevice.current.userInterfaceIdiom
            
            if deviceIdiom == .pad {
                return self.createiPadSection(layoutEnvironment: layoutEnvironment)
            } else {
                return self.createiPhoneSection()
            }
        }
        
        return layout
    }
    
    private func createiPadSection(layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(0.5),
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
        
        return section
    }
    
    private func createiPhoneSection() -> NSCollectionLayoutSection {
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
        
        return section
    }
    
    // MARK: - Actions
    
    @objc private func refreshData() {
        dataService.refreshData()
    }
    
    @objc private func addNoteTapped() {
        // Implement add note functionality
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Collection View Data Source & Delegate

extension OptimizedNotesViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return dataService.notesSubject.value.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: OptimizedNoteCell.identifier, for: indexPath) as! OptimizedNoteCell
        
        if let note = dataService.getNote(at: indexPath.item) {
            cell.configure(with: note)
        }
        
        // Prefetch next page if needed
        dataService.prefetchIfNeeded(currentIndex: indexPath.item)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        if let note = dataService.getNote(at: indexPath.item) {
            // Navigate to note detail
        }
    }
}
