import Foundation
import UIKit
import Combine

// MARK: - Performance Manager

class PerformanceManager {
    static let shared = PerformanceManager()
    
    private let memoryMonitor = MemoryMonitor()
    private let performanceTracker = PerformanceTracker()
    private let imageCache = ImageCache()
    
    private init() {
        setupMemoryWarningObserver()
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(memoryWarningReceived),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func memoryWarningReceived() {
        // Clear caches and free up memory
        imageCache.clearCache()
        memoryMonitor.logMemoryUsage()
    }
    
    func startPerformanceMonitoring() {
        performanceTracker.startMonitoring()
    }
    
    func stopPerformanceMonitoring() {
        performanceTracker.stopMonitoring()
    }
}

// MARK: - Memory Monitor

class MemoryMonitor {
    private var memoryUsageTimer: Timer?
    
    func startMonitoring() {
        memoryUsageTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.logMemoryUsage()
        }
    }
    
    func stopMonitoring() {
        memoryUsageTimer?.invalidate()
        memoryUsageTimer = nil
    }
    
    func logMemoryUsage() {
        let memoryInfo = getMemoryInfo()
        print("Memory Usage - Used: \(memoryInfo.used)MB, Available: \(memoryInfo.available)MB")
        
        // Log to analytics or crash reporting service
        if memoryInfo.used > 200 { // More than 200MB
            print("⚠️ High memory usage detected")
        }
    }
    
    private func getMemoryInfo() -> (used: Int, available: Int) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMB = Int(info.resident_size / 1024 / 1024)
            let totalMB = Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024)
            let availableMB = totalMB - usedMB
            return (used: usedMB, available: availableMB)
        }
        
        return (used: 0, available: 0)
    }
}

// MARK: - Performance Tracker

class PerformanceTracker {
    private var startTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var displayLink: CADisplayLink?
    
    func startMonitoring() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func stopMonitoring() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func displayLinkTick() {
        frameCount += 1
        
        if frameCount % 60 == 0 { // Check every 60 frames (1 second)
            let fps = displayLink?.timestamp ?? 0
            if fps < 55 { // Below 55 FPS indicates performance issues
                print("⚠️ Low FPS detected: \(fps)")
            }
        }
    }
    
    func measureOperation<T>(_ operation: () throws -> T) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        
        if duration > 0.1 { // Operations taking more than 100ms
            print("⚠️ Slow operation detected: \(duration)s")
        }
        
        return (result: result, duration: duration)
    }
}

// MARK: - Image Cache

class ImageCache {
    private let cache = NSCache<NSString, UIImage>()
    private let maxCacheSize = 50 * 1024 * 1024 // 50MB
    
    init() {
        cache.totalCostLimit = maxCacheSize
        cache.countLimit = 100
    }
    
    func image(for key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }
    
    func setImage(_ image: UIImage, for key: String) {
        let cost = imageCost(image)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    func clearCache() {
        cache.removeAllObjects()
    }
    
    private func imageCost(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.width * cgImage.height * 4 // 4 bytes per pixel (RGBA)
    }
}

// MARK: - Lazy Loading Collection View

class LazyLoadingCollectionView: UICollectionView {
    private let prefetchDistance = 10
    private var visibleIndexPaths: Set<IndexPath> = []
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateVisibleCells()
    }
    
    private func updateVisibleCells() {
        let newVisibleIndexPaths = Set(indexPathsForVisibleItems)
        let newlyVisible = newVisibleIndexPaths.subtracting(visibleIndexPaths)
        let noLongerVisible = visibleIndexPaths.subtracting(newVisibleIndexPaths)
        
        // Load newly visible cells
        for indexPath in newlyVisible {
            loadCell(at: indexPath)
        }
        
        // Unload cells that are no longer visible
        for indexPath in noLongerVisible {
            unloadCell(at: indexPath)
        }
        
        visibleIndexPaths = newVisibleIndexPaths
    }
    
    private func loadCell(at indexPath: IndexPath) {
        // Implement lazy loading logic here
        // This could involve loading images, fetching data, etc.
    }
    
    private func unloadCell(at indexPath: IndexPath) {
        // Implement cleanup logic here
        // This could involve releasing images, clearing caches, etc.
    }
}

// MARK: - Background Task Manager

class BackgroundTaskManager {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let syncService: SyncServiceProtocol
    
    init(syncService: SyncServiceProtocol = SyncService()) {
        self.syncService = syncService
        setupBackgroundNotifications()
    }
    
    private func setupBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        startBackgroundSync()
    }
    
    @objc private func appWillEnterForeground() {
        endBackgroundSync()
    }
    
    private func startBackgroundSync() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "BackgroundSync") { [weak self] in
            self?.endBackgroundSync()
        }
        
        Task {
            do {
                try await syncService.syncNotes()
            } catch {
                print("Background sync failed: \(error)")
            }
            endBackgroundSync()
        }
    }
    
    private func endBackgroundSync() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }
}

// MARK: - Optimized Note Service

class OptimizedNoteService: NoteServiceProtocol {
    private let coreDataStack = CoreDataStack.shared
    private let batchSize = 20
    private let cache = NSCache<NSString, [Note]>()
    
    init() {
        cache.countLimit = 10
    }
    
    func fetchAllNotes() async throws -> [Note] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    request.fetchBatchSize = self.batchSize
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
    
    func fetchNotesBatch(offset: Int, limit: Int) async throws -> [Note] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    request.fetchOffset = offset
                    request.fetchLimit = limit
                    request.sortDescriptors = [
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
    
    func saveNote(_ note: Note) async throws -> Note {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let entity = NoteEntity(context: context)
                    self.populateEntity(entity, with: note)
                    
                    try context.save()
                    coreDataStack.saveContext()
                    
                    // Clear cache to ensure fresh data
                    self.cache.removeAllObjects()
                    
                    let savedNote = self.convertEntityToNote(entity) ?? note
                    continuation.resume(returning: savedNote)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func updateNote(_ note: Note) async throws -> Note {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", note.id as CVarArg)
                    
                    guard let entity = try context.fetch(request).first else {
                        continuation.resume(throwing: NoteServiceError.noteNotFound)
                        return
                    }
                    
                    self.populateEntity(entity, with: note)
                    entity.updatedAt = Date()
                    entity.syncStatusEnum = .pending
                    
                    try context.save()
                    coreDataStack.saveContext()
                    
                    // Clear cache
                    self.cache.removeAllObjects()
                    
                    let updatedNote = self.convertEntityToNote(entity) ?? note
                    continuation.resume(returning: updatedNote)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteNote(_ id: UUID) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let context = coreDataStack.context
            context.perform {
                do {
                    let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    
                    guard let entity = try context.fetch(request).first else {
                        continuation.resume(throwing: NoteServiceError.noteNotFound)
                        return
                    }
                    
                    context.delete(entity)
                    try context.save()
                    coreDataStack.saveContext()
                    
                    // Clear cache
                    self.cache.removeAllObjects()
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func searchNotes(query: String) async throws -> [Note] {
        // Check cache first
        let cacheKey = "search_\(query)" as NSString
        if let cachedNotes = cache.object(forKey: cacheKey) {
            return cachedNotes
        }
        
        let notes = try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    request.predicate = NSPredicate(
                        format: "title CONTAINS[cd] %@ OR content CONTAINS[cd] %@",
                        query, query
                    )
                    request.sortDescriptors = [
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
        
        // Cache the results
        cache.setObject(notes, forKey: cacheKey)
        
        return notes
    }
    
    // MARK: - Private Helpers
    
    private func convertEntityToNote(_ entity: NoteEntity) -> Note? {
        var note = Note(title: entity.title, content: entity.content, tags: entity.tags, color: entity.color)
        note.id = entity.id
        note.createdAt = entity.createdAt
        note.updatedAt = entity.updatedAt
        note.isEncrypted = entity.isEncrypted
        note.isPinned = entity.isPinned
        
        return note
    }
    
    private func populateEntity(_ entity: NoteEntity, with note: Note) {
        entity.id = note.id
        entity.title = note.title
        entity.content = note.content
        entity.createdAt = note.createdAt
        entity.updatedAt = note.updatedAt
        entity.tags = note.tags
        entity.isEncrypted = note.isEncrypted
        entity.isPinned = note.isPinned
        entity.color = note.color
        entity.syncStatusEnum = .pending
    }
}

// MARK: - Performance Optimized View Controller

class PerformanceOptimizedNotesViewController: NotesViewController {
    private let performanceManager = PerformanceManager.shared
    private let backgroundTaskManager = BackgroundTaskManager()
    private let optimizedNoteService = OptimizedNoteService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupPerformanceOptimizations()
    }
    
    private func setupPerformanceOptimizations() {
        // Start performance monitoring
        performanceManager.startPerformanceMonitoring()
        
        // Configure collection view for better performance
        collectionView.prefetchDataSource = self
        collectionView.isPrefetchingEnabled = true
        
        // Use optimized note service
        // Note: In a real implementation, you'd inject this through dependency injection
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        performanceManager.stopPerformanceMonitoring()
    }
}

// MARK: - Collection View Prefetching

extension PerformanceOptimizedNotesViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // Prefetch data for upcoming cells
        for indexPath in indexPaths {
            if indexPath.item < viewModel.filteredNotes.count {
                let note = viewModel.filteredNotes[indexPath.item]
                // Prefetch any heavy data (images, etc.)
                prefetchNoteData(note)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Cancel prefetching if no longer needed
        for indexPath in indexPaths {
            cancelPrefetchForIndexPath(indexPath)
        }
    }
    
    private func prefetchNoteData(_ note: Note) {
        // Implement prefetching logic here
        // This could involve loading images, preparing data, etc.
    }
    
    private func cancelPrefetchForIndexPath(_ indexPath: IndexPath) {
        // Implement cancellation logic here
    }
}
