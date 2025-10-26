import Foundation
import Combine
import Network
import os.log

// MARK: - Improved Sync Service with Concurrency Control

class ImprovedSyncService: SyncServiceProtocol {
    private let apiClient: APIClient
    private let noteService: NoteServiceProtocol
    private let deviceId: String
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    // Concurrency control
    private let syncQueue = DispatchQueue(label: "sync.queue", qos: .utility)
    private let syncSemaphore = DispatchSemaphore(value: 1)
    private var isSyncing = false
    private var syncTask: Task<Void, Error>?
    
    // Performance optimization
    private let batchSize = 50
    private let maxConcurrentOperations = 5
    
    // Logging
    private let logger = Logger(subsystem: "com.apple.smartnotes", category: "sync")
    
    init(apiClient: APIClient = APIClient(), noteService: NoteServiceProtocol = NoteService()) {
        self.apiClient = apiClient
        self.noteService = noteService
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        
        setupNetworkMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Task {
                    try? await self?.syncNotes()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Thread-Safe Sync Operations
    
    func syncNotes() async throws {
        // Prevent concurrent sync operations
        guard syncSemaphore.wait(timeout: .now() + 0.1) == .success else {
            logger.warning("Sync already in progress, skipping")
            return
        }
        
        defer { syncSemaphore.signal() }
        
        // Cancel any existing sync task
        syncTask?.cancel()
        
        syncTask = Task {
            try await performSync()
        }
        
        try await syncTask?.value
    }
    
    private func performSync() async throws {
        logger.info("Starting sync operation")
        
        // Check network connectivity
        guard await isNetworkAvailable() else {
            logger.warning("Network unavailable, skipping sync")
            throw SyncError.networkUnavailable
        }
        
        // Get sync metadata efficiently
        let syncMetadata = try await getSyncMetadata()
        
        // Create optimized sync request
        let syncRequest = NoteSyncRequest(
            deviceId: deviceId,
            lastSyncTimestamp: syncMetadata.lastSyncTimestamp,
            notes: syncMetadata.pendingNotes,
            deletedNoteIds: syncMetadata.deletedNoteIds,
            conflicts: []
        )
        
        logger.info("Syncing \(syncMetadata.pendingNotes.count) pending notes")
        
        // Send sync request to server
        let syncResponse = try await apiClient.syncNotes(syncRequest)
        
        // Process server response with concurrency control
        try await processSyncResponseOptimized(syncResponse)
        
        // Update sync timestamp atomically
        try await updateSyncTimestamp()
        
        logger.info("Sync operation completed successfully")
    }
    
    // MARK: - Optimized Data Processing
    
    private func getSyncMetadata() async throws -> SyncMetadata {
        return try await withCheckedThrowingContinuation { continuation in
            let context = CoreDataStack.shared.context
            context.perform {
                do {
                    // Only fetch pending sync notes (not all notes)
                    let pendingRequest: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    pendingRequest.predicate = NSPredicate(format: "syncStatus == %@", "pending")
                    pendingRequest.sortDescriptors = [
                        NSSortDescriptor(keyPath: \NoteEntity.updatedAt, ascending: false)
                    ]
                    pendingRequest.fetchLimit = 100 // Limit for performance
                    
                    let pendingEntities = try context.fetch(pendingRequest)
                    let pendingNotes = pendingEntities.compactMap { self.convertEntityToNote($0) }
                    
                    // Get deleted notes
                    let deletedRequest: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
                    deletedRequest.predicate = NSPredicate(format: "syncStatus == %@", "deleted")
                    let deletedEntities = try context.fetch(deletedRequest)
                    let deletedNoteIds = deletedEntities.map { $0.id }
                    
                    let lastSyncTimestamp = UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date ?? Date.distantPast
                    
                    let metadata = SyncMetadata(
                        lastSyncTimestamp: lastSyncTimestamp,
                        pendingNotes: pendingNotes,
                        deletedNoteIds: deletedNoteIds
                    )
                    
                    continuation.resume(returning: metadata)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func processSyncResponseOptimized(_ response: NoteSyncResponse) async throws {
        // Process conflicts and notes concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Add conflict resolution tasks
            for conflict in response.conflicts {
                group.addTask {
                    try await self.resolveConflict(conflict, resolution: .useLocal)
                }
            }
            
            // Add note update tasks (batched for performance)
            let noteBatches = response.notes.chunked(into: batchSize)
            for batch in noteBatches {
                group.addTask {
                    try await self.updateNotesBatch(batch)
                }
            }
            
            // Wait for all operations to complete
            try await group.waitForAll()
        }
    }
    
    private func updateNotesBatch(_ notes: [Note]) async throws {
        // Process batch with limited concurrency
        try await withThrowingTaskGroup(of: Void.self) { group in
            let semaphore = DispatchSemaphore(value: maxConcurrentOperations)
            
            for note in notes {
                group.addTask {
                    await semaphore.wait()
                    defer { semaphore.signal() }
                    
                    try await self.noteService.updateNote(note)
                }
            }
            
            try await group.waitForAll()
        }
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflict(_ conflict: NoteConflict, resolution: ConflictResolution) async throws {
        let resolvedNote: Note
        
        switch resolution {
        case .useLocal:
            resolvedNote = conflict.localVersion
        case .useServer:
            resolvedNote = conflict.serverVersion
        case .merge:
            resolvedNote = try mergeNotes(local: conflict.localVersion, server: conflict.serverVersion)
        }
        
        // Mark as resolved and update
        var updatedNote = resolvedNote
        updatedNote.updatedAt = Date()
        
        try await noteService.updateNote(updatedNote)
        try await noteService.markNoteAsSynced(resolvedNote.id)
    }
    
    private func mergeNotes(local: Note, server: Note) throws -> Note {
        // Improved merge strategy with conflict markers
        var mergedNote = local
        
        // Use more recent title
        if server.updatedAt > local.updatedAt {
            mergedNote.title = server.title
        }
        
        // Merge content with conflict markers
        if local.content != server.content {
            mergedNote.content = """
            \(local.content)
            
            --- CONFLICT RESOLUTION ---
            Server version (\(server.updatedAt)):
            \(server.content)
            """
        }
        
        mergedNote.updatedAt = max(local.updatedAt, server.updatedAt)
        mergedNote.tags = Array(Set(local.tags + server.tags))
        
        return mergedNote
    }
    
    // MARK: - Atomic Operations
    
    private func updateSyncTimestamp() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async {
                UserDefaults.standard.set(Date(), forKey: "lastSyncTimestamp")
                continuation.resume()
            }
        }
    }
    
    // MARK: - Network Monitoring
    
    private func isNetworkAvailable() async -> Bool {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                continuation.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue.global())
        }
    }
    
    // MARK: - Helper Methods
    
    private func convertEntityToNote(_ entity: NoteEntity) -> Note? {
        var note = Note(title: entity.title, content: entity.content, tags: entity.tags, color: entity.color)
        note.id = entity.id
        note.createdAt = entity.createdAt
        note.updatedAt = entity.updatedAt
        note.isEncrypted = entity.isEncrypted
        note.isPinned = entity.isPinned
        
        return note
    }
}

// MARK: - Supporting Types

struct SyncMetadata {
    let lastSyncTimestamp: Date
    let pendingNotes: [Note]
    let deletedNoteIds: [UUID]
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Improved Background Sync Manager

class ImprovedBackgroundSyncManager {
    private let syncService: SyncServiceProtocol
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let syncQueue = DispatchQueue(label: "background.sync", qos: .utility)
    
    // Prevent multiple background syncs
    private var isBackgroundSyncing = false
    private let backgroundSyncSemaphore = DispatchSemaphore(value: 1)
    
    init(syncService: SyncServiceProtocol = ImprovedSyncService()) {
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
        
        // Start foreground sync with delay to avoid conflicts
        syncQueue.asyncAfter(deadline: .now() + 1.0) {
            Task {
                try? await self.syncService.syncNotes()
            }
        }
    }
    
    private func startBackgroundSync() {
        // Prevent concurrent background syncs
        guard backgroundSyncSemaphore.wait(timeout: .now() + 0.1) == .success else {
            return
        }
        
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "BackgroundSync") { [weak self] in
            self?.endBackgroundSync()
        }
        
        syncQueue.async {
            Task {
                do {
                    try await self.syncService.syncNotes()
                } catch {
                    print("Background sync failed: \(error)")
                }
                self.endBackgroundSync()
            }
        }
    }
    
    private func endBackgroundSync() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        backgroundSyncSemaphore.signal()
    }
}

// MARK: - Enhanced Note Service with Sync Status

extension NoteServiceProtocol {
    func markNoteAsSynced(_ id: UUID) async throws {
        // Implementation would update sync status in Core Data
        // This prevents re-syncing already synced notes
    }
    
    func markNoteForDeletion(_ id: UUID) async throws {
        // Mark note for deletion instead of immediate deletion
        // This allows for proper sync of deletions
    }
}
