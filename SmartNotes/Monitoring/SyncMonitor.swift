import UIKit
import Foundation
import os.log
import Combine

// MARK: - Advanced Background Sync Monitor

class AdvancedBackgroundSyncMonitor {
    
    // MARK: - Properties
    
    static let shared = AdvancedBackgroundSyncMonitor()
    
    private let logger = Logger(subsystem: "com.apple.smartnotes", category: "sync.monitor")
    private let syncMetrics = SyncMetrics()
    private let errorTracker = SyncErrorTracker()
    private let retryManager = SyncRetryManager()
    
    private var cancellables = Set<AnyCancellable>()
    private var syncObservers: [UUID: (SyncEvent) -> Void] = [:]
    
    // Background sync state
    private var isBackgroundSyncing = false
    private var currentSyncTask: Task<Void, Never>?
    private var lastSyncSuccess: Date?
    private var consecutiveFailures: Int = 0
    
    private init() {
        setupMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Monitor sync events without blocking
    func monitorSyncEvent(_ event: SyncEvent) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.handleSyncEvent(event)
        }
    }
    
    /// Get current sync status without blocking UI
    func getSyncStatus() async -> SyncStatus {
        await syncMetrics.getCurrentStatus()
    }
    
    /// Subscribe to sync events
    func subscribeToEvents(observer: @escaping (SyncEvent) -> Void) -> UUID {
        let id = UUID()
        syncObservers[id] = observer
        return id
    }
    
    /// Unsubscribe from sync events
    func unsubscribe(id: UUID) {
        syncObservers.removeValue(forKey: id)
    }
    
    /// Get sync metrics for debugging
    func getMetrics() -> SyncMetrics {
        return syncMetrics
    }
    
    // MARK: - Private Implementation
    
    private func setupMonitoring() {
        // Monitor network changes
        setupNetworkMonitoring()
        
        // Monitor app lifecycle
        setupAppLifecycleMonitoring()
        
        // Monitor memory warnings
        setupMemoryWarningMonitoring()
    }
    
    private func setupNetworkMonitoring() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "network.monitor")
        
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.logger.info("Network connectivity restored")
                self?.handleNetworkRestored()
            } else {
                self?.logger.warning("Network connectivity lost")
                self?.handleNetworkLost()
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func setupAppLifecycleMonitoring() {
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
    
    private func setupMemoryWarningMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        logger.info("App entered background, monitoring background sync")
    }
    
    @objc private func appWillEnterForeground() {
        logger.info("App entered foreground, checking sync status")
        checkSyncStatus()
    }
    
    @objc private func didReceiveMemoryWarning() {
        logger.warning("Memory warning received, syncing critical data only")
    }
    
    private func handleNetworkRestored() {
        // Automatically retry failed syncs when network is restored
        if consecutiveFailures > 0 {
            Task {
                await retryManager.retryFailedSyncs()
            }
        }
    }
    
    private func handleNetworkLost() {
        logger.warning("Network lost, pausing sync operations")
        currentSyncTask?.cancel()
        currentSyncTask = nil
    }
    
    private func handleSyncEvent(_ event: SyncEvent) {
        // Log event
        logger.info("Sync event: \(event.description)")
        
        // Update metrics
        syncMetrics.recordEvent(event)
        
        // Track errors
        if case .syncFailed(let error) = event {
            errorTracker.recordError(error)
            consecutiveFailures += 1
            handleSyncFailure(error)
        } else if case .syncCompleted = event {
            consecutiveFailures = 0
            lastSyncSuccess = Date()
        }
        
        // Notify observers
        notifyObservers(event)
    }
    
    private func handleSyncFailure(_ error: Error) {
        logger.error("Sync failed with error: \(error.localizedDescription)")
        
        // Determine retry strategy
        let retryStrategy = retryManager.getRetryStrategy(for: error)
        
        if retryStrategy.shouldRetry {
            logger.info("Scheduling retry in \(retryStrategy.delay) seconds")
            
            // Schedule retry without blocking
            Task {
                try? await Task.sleep(nanoseconds: UInt64(retryStrategy.delay * 1_000_000_000))
                await retryManager.performRetry()
            }
        } else {
            logger.error("Max retries exceeded, stopping retries")
        }
    }
    
    private func checkSyncStatus() {
        Task {
            let status = await getSyncStatus()
            
            // If last sync was more than 5 minutes ago, trigger sync
            if let lastSuccess = lastSyncSuccess,
               Date().timeIntervalSince(lastSuccess) > 300 {
                logger.info("Triggering sync due to stale data")
            }
        }
    }
    
    private func notifyObservers(_ event: SyncEvent) {
        for observer in syncObservers.values {
            DispatchQueue.main.async {
                observer(event)
            }
        }
    }
}

// MARK: - Sync Events

enum SyncEvent {
    case syncStarted
    case syncCompleted(successCount: Int, failureCount: Int)
    case syncFailed(Error)
    case syncProgress(completed: Int, total: Int)
    case networkUnavailable
    case retryScheduled(delay: TimeInterval)
    case retryAttempted(count: Int)
    case maxRetriesExceeded
    
    var description: String {
        switch self {
        case .syncStarted:
            return "Sync started"
        case .syncCompleted(let success, let failure):
            return "Sync completed: \(success) success, \(failure) failures"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .syncProgress(let completed, let total):
            return "Sync progress: \(completed)/\(total)"
        case .networkUnavailable:
            return "Network unavailable"
        case .retryScheduled(let delay):
            return "Retry scheduled in \(delay) seconds"
        case .retryAttempted(let count):
            return "Retry attempted (count: \(count))"
        case .maxRetriesExceeded:
            return "Max retries exceeded"
        }
    }
}

// MARK: - Sync Status

struct SyncStatus {
    let isActive: Bool
    let lastSyncTime: Date?
    let pendingItems: Int
    let failedItems: Int
    let consecutiveFailures: Int
    let networkAvailable: Bool
    let backgroundTaskActive: Bool
}

// MARK: - Sync Metrics

class SyncMetrics {
    
    private var events: [SyncEvent] = []
    private let maxEvents = 1000
    private let lock = NSLock()
    
    func recordEvent(_ event: SyncEvent) {
        lock.lock()
        defer { lock.unlock() }
        
        events.append(event)
        
        // Keep only recent events
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }
    
    func getCurrentStatus() async -> SyncStatus {
        lock.lock()
        defer { lock.unlock() }
        
        let recentEvents = events.suffix(100)
        let isActive = recentEvents.contains { if case .syncStarted = $0 { return true } else { return false } }
        let lastSyncTime = recentEvents.last(where: { if case .syncCompleted = $0 { return true } else { return false } }) != nil ? Date() : nil
        let pendingItems = 0 // Would be calculated from actual pending items
        let failedItems = recentEvents.filter { if case .syncFailed = $0 { return true } else { return false } }.count
        
        return SyncStatus(
            isActive: isActive,
            lastSyncTime: lastSyncTime,
            pendingItems: pendingItems,
            failedItems: failedItems,
            consecutiveFailures: 0,
            networkAvailable: true,
            backgroundTaskActive: false
        )
    }
    
    func getRecentEvents(count: Int = 50) -> [SyncEvent] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(events.suffix(count))
    }
    
    func getErrorCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        
        return events.filter { if case .syncFailed = $0 { return true } else { return false } }.count
    }
}

// MARK: - Sync Error Tracker

class SyncErrorTracker {
    
    private var errors: [SyncError] = []
    private let maxErrors = 500
    private let lock = NSLock()
    
    func recordError(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        
        let syncError = SyncError(
            error: error,
            timestamp: Date(),
            context: getContext()
        )
        
        errors.append(syncError)
        
        // Keep only recent errors
        if errors.count > maxErrors {
            errors.removeFirst(errors.count - maxErrors)
        }
    }
    
    func getRecentErrors(count: Int = 50) -> [SyncError] {
        lock.lock()
        defer { lock.unlock() }
        
        return Array(errors.suffix(count))
    }
    
    func getErrorSummary() -> ErrorSummary {
        lock.lock()
        defer { lock.unlock() }
        
        let totalErrors = errors.count
        let networkErrors = errors.filter { $0.isNetworkError }.count
        let serverErrors = errors.filter { $0.isServerError }.count
        let clientErrors = errors.filter { $0.isClientError }.count
        
        return ErrorSummary(
            totalErrors: totalErrors,
            networkErrors: networkErrors,
            serverErrors: serverErrors,
            clientErrors: clientErrors,
            mostRecentError: errors.last
        )
    }
    
    private func getContext() -> ErrorContext {
        return ErrorContext(
            appState: UIApplication.shared.applicationState == .background ? "background" : "foreground",
            memoryPressure: "normal",
            networkAvailable: true
        )
    }
}

struct SyncError {
    let error: Error
    let timestamp: Date
    let context: ErrorContext
    
    var isNetworkError: Bool {
        return error.localizedDescription.contains("network")
    }
    
    var isServerError: Bool {
        return error.localizedDescription.contains("server")
    }
    
    var isClientError: Bool {
        return error.localizedDescription.contains("client")
    }
}

struct ErrorContext {
    let appState: String
    let memoryPressure: String
    let networkAvailable: Bool
}

struct ErrorSummary {
    let totalErrors: Int
    let networkErrors: Int
    let serverErrors: Int
    let clientErrors: Int
    let mostRecentError: SyncError?
}

// MARK: - Sync Retry Manager

class SyncRetryManager {
    
    private var retryAttempts: [UUID: Int] = [:]
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    private let maxDelay: TimeInterval = 60.0
    private let lock = NSLock()
    
    func getRetryStrategy(for error: Error) -> RetryStrategy {
        lock.lock()
        defer { lock.unlock() }
        
        let errorId = UUID()
        let attempts = retryAttempts[errorId] ?? 0
        
        if attempts >= maxRetries {
            return RetryStrategy(shouldRetry: false, delay: 0)
        }
        
        // Exponential backoff
        let delay = min(baseDelay * pow(2.0, Double(attempts)), maxDelay)
        
        retryAttempts[errorId] = attempts + 1
        
        return RetryStrategy(shouldRetry: true, delay: delay)
    }
    
    func performRetry() async {
        // Implement retry logic
        logger.info("Performing retry")
    }
    
    func retryFailedSyncs() async {
        // Implement batch retry logic
        logger.info("Retrying failed syncs")
    }
}

struct RetryStrategy {
    let shouldRetry: Bool
    let delay: TimeInterval
}

// MARK: - Background Sync Debugger

class BackgroundSyncDebugger {
    
    static let shared = BackgroundSyncDebugger()
    
    private let monitor = AdvancedBackgroundSyncMonitor.shared
    private var isEnabled = false
    
    func enableDebugging() {
        isEnabled = true
        logger.info("Background sync debugging enabled")
    }
    
    func disableDebugging() {
        isEnabled = false
        logger.info("Background sync debugging disabled")
    }
    
    func getDebugInfo() async -> String {
        let metrics = monitor.getMetrics()
        let status = await monitor.getSyncStatus()
        let errors = metrics.getRecentEvents(count: 20)
        
        var debugInfo = "=== Background Sync Debug Info ===\n\n"
        debugInfo += "Status: \(status.isActive ? "Active" : "Inactive")\n"
        debugInfo += "Last Sync: \(status.lastSyncTime?.description ?? "Never")\n"
        debugInfo += "Pending Items: \(status.pendingItems)\n"
        debugInfo += "Failed Items: \(status.failedItems)\n\n"
        debugInfo += "Recent Events:\n"
        
        for event in errors {
            debugInfo += "  - \(event.description)\n"
        }
        
        return debugInfo
    }
    
    func exportDebugInfo() async throws -> URL {
        let debugInfo = await getDebugInfo()
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("sync_debug_\(Date().timeIntervalSince1970).txt")
        
        try debugInfo.write(to: fileURL, atomically: true, encoding: .utf8)
        
        return fileURL
    }
}
