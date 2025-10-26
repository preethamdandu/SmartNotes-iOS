import Foundation
import Combine
import Network

// MARK: - Sync Service

class SyncService: SyncServiceProtocol {
    private let apiClient: APIClient
    private let noteService: NoteServiceProtocol
    private let deviceId: String
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
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
    
    func syncNotes() async throws {
        // Check network connectivity
        guard await isNetworkAvailable() else {
            throw SyncError.networkUnavailable
        }
        
        // Get local notes and last sync timestamp
        let localNotes = try await noteService.fetchAllNotes()
        let lastSyncTimestamp = UserDefaults.standard.object(forKey: "lastSyncTimestamp") as? Date ?? Date.distantPast
        
        // Create sync request
        let syncRequest = NoteSyncRequest(
            notes: localNotes,
            lastSyncTimestamp: lastSyncTimestamp,
            deviceId: deviceId
        )
        
        // Send sync request to server
        let syncResponse = try await apiClient.syncNotes(syncRequest)
        
        // Process server response
        try await processSyncResponse(syncResponse)
        
        // Update last sync timestamp
        UserDefaults.standard.set(Date(), forKey: "lastSyncTimestamp")
    }
    
    private func processSyncResponse(_ response: NoteSyncResponse) async throws {
        // Handle conflicts first
        for conflict in response.conflicts {
            try await resolveConflict(conflict, resolution: .useLocal) // Default resolution
        }
        
        // Update local notes with server data
        for serverNote in response.notes {
            try await noteService.updateNote(serverNote)
        }
    }
    
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
        
        try await noteService.updateNote(resolvedNote)
    }
    
    private func mergeNotes(local: Note, server: Note) throws -> Note {
        // Simple merge strategy: combine content and use latest timestamp
        var mergedNote = local
        mergedNote.title = server.title // Use server title as it might be more recent
        mergedNote.content = "\(local.content)\n\n--- Merged with server version ---\n\n\(server.content)"
        mergedNote.updatedAt = max(local.updatedAt, server.updatedAt)
        mergedNote.tags = Array(Set(local.tags + server.tags)) // Combine unique tags
        
        return mergedNote
    }
    
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
}

// MARK: - API Client

class APIClient {
    private let baseURL = "https://api.smartnotes.app" // Replace with actual API endpoint
    private let session = URLSession.shared
    
    func syncNotes(_ request: NoteSyncRequest) async throws -> NoteSyncResponse {
        let url = URL(string: "\(baseURL)/sync")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(request)
        urlRequest.httpBody = jsonData
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse<NoteSyncResponse>.self, from: data)
        
        guard apiResponse.success,
              let syncResponse = apiResponse.data else {
            throw APIError.invalidResponse
        }
        
        return syncResponse
    }
    
    func uploadNote(_ note: Note) async throws {
        let url = URL(string: "\(baseURL)/notes")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let jsonData = try JSONEncoder().encode(note)
        urlRequest.httpBody = jsonData
        
        let (_, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            throw APIError.requestFailed
        }
    }
    
    func downloadNotes(since timestamp: Date) async throws -> [Note] {
        let url = URL(string: "\(baseURL)/notes?since=\(timestamp.timeIntervalSince1970)")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.requestFailed
        }
        
        let apiResponse = try JSONDecoder().decode(APIResponse<[Note]>.self, from: data)
        
        guard apiResponse.success,
              let notes = apiResponse.data else {
            throw APIError.invalidResponse
        }
        
        return notes
    }
}

// MARK: - Background Sync Manager

class BackgroundSyncManager {
    private let syncService: SyncServiceProtocol
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    init(syncService: SyncServiceProtocol = SyncService()) {
        self.syncService = syncService
        setupBackgroundSync()
    }
    
    private func setupBackgroundSync() {
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
        Task {
            try? await syncService.syncNotes()
        }
    }
    
    private func startBackgroundSync() {
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "SyncNotes") { [weak self] in
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

// MARK: - Errors

enum SyncError: Error, LocalizedError {
    case networkUnavailable
    case syncFailed(String)
    case conflictResolutionFailed
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network connection is not available"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflicts"
        }
    }
}

enum APIError: Error, LocalizedError {
    case requestFailed
    case invalidResponse
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .requestFailed:
            return "API request failed"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}
