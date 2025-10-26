import UIKit
import Foundation
import os.log
import Combine
import Network

// MARK: - Enhanced Background Sync Service with Monitoring

class MonitoredBackgroundSyncService {
    
    // MARK: - Properties
    
    private let syncService: SyncServiceProtocol
    private let monitor = AdvancedBackgroundSyncMonitor.shared
    private let logger = Logger(subsystem: "com.apple.smartnotes", category: "background.sync")
    
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var syncTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    
    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "network.monitor")
    
    // Retry configuration
    private let maxRetries = 3
    private let retryDelays: [TimeInterval] = [1.0, 5.0, 30.0]
    private var currentRetryAttempt = 0
    
    init(syncService: SyncServiceProtocol = ImprovedSyncService()) {
        self.syncService = syncService
        setupNetworkMonitoring()
        setupAppLifecycle()
    }
    
    // MARK: - Setup
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.logger.info("Network available, checking for pending syncs")
                self?.handleNetworkAvailable()
            } else {
                self?.logger.warning("Network unavailable, postponing syncs")
                self?.monitor.monitorSyncEvent(.networkUnavailable)
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    private func setupAppLifecycle() {
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
    
    // MARK: - Background Sync
    
    @objc private func appDidEnterBackground() {
        logger.info("App entered background, starting background sync")
        performBackgroundSync()
    }
    
    @objc private func appWillEnterForeground() {
        logger.info("App entered foreground, ending background sync")
        endBackgroundTask()
    }
    
    private func performBackgroundSync() {
        guard networkMonitor.currentPath.status == .satisfied else {
            logger.warning("Network unavailable for background sync")
            monitor.monitorSyncEvent(.networkUnavailable)
            return
        }
        
        // Cancel any existing sync
        syncTask?.cancel()
        
        // Start background task
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "BackgroundSync") { [weak self] in
            self?.endBackgroundTask()
        }
        
        // Perform sync
        syncTask = Task { [weak self] in
            guard let self = self else { return }
            
            do {
                self.monitor.monitorSyncEvent(.syncStarted)
                self.logger.info("Starting background sync")
                
                try await self.syncService.syncNotes()
                
                self.monitor.monitorSyncEvent(.syncCompleted(successCount: 1, failureCount: 0))
                self.logger.info("Background sync completed successfully")
                self.currentRetryAttempt = 0
                
            } catch {
                self.handleSyncError(error)
            }
            
            self.endBackgroundTask()
        }
    }
    
    private func handleSyncError(_ error: Error) {
        logger.error("Background sync failed: \(error.localizedDescription)")
        monitor.monitorSyncEvent(.syncFailed(error))
        
        // Schedule retry if within limits
        if currentRetryAttempt < maxRetries {
            scheduleRetry()
        } else {
            logger.error("Max retries exceeded, stopping retries")
            monitor.monitorSyncEvent(.maxRetriesExceeded)
        }
    }
    
    private func scheduleRetry() {
        guard currentRetryAttempt < retryDelays.count else {
            logger.error("Retry delay index out of bounds")
            return
        }
        
        let delay = retryDelays[currentRetryAttempt]
        currentRetryAttempt += 1
        
        logger.info("Scheduling retry in \(delay) seconds (attempt \(currentRetryAttempt)/\(maxRetries))")
        monitor.monitorSyncEvent(.retryScheduled(delay: delay))
        
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            guard let self = self else { return }
            
            if networkMonitor.currentPath.status == .satisfied {
                self.logger.info("Retrying background sync")
                self.monitor.monitorSyncEvent(.retryAttempted(count: self.currentRetryAttempt))
                self.performBackgroundSync()
            } else {
                self.logger.warning("Network still unavailable, skipping retry")
            }
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        syncTask?.cancel()
        syncTask = nil
    }
    
    private func handleNetworkAvailable() {
        // If we have pending retries, trigger sync
        if currentRetryAttempt > 0 {
            logger.info("Network restored, triggering sync")
            performBackgroundSync()
        }
    }
    
    // MARK: - Public Interface
    
    func forceSync() async throws {
        logger.info("Forcing manual sync")
        monitor.monitorSyncEvent(.syncStarted)
        
        do {
            try await syncService.syncNotes()
            monitor.monitorSyncEvent(.syncCompleted(successCount: 1, failureCount: 0))
            currentRetryAttempt = 0
        } catch {
            monitor.monitorSyncEvent(.syncFailed(error))
            throw error
        }
    }
    
    func getSyncStatus() async -> SyncStatus {
        return await monitor.getSyncStatus()
    }
    
    func subscribeToEvents(observer: @escaping (SyncEvent) -> Void) -> UUID {
        return monitor.subscribeToEvents(observer: observer)
    }
    
    func unsubscribe(id: UUID) {
        monitor.unsubscribe(id: id)
    }
}

// MARK: - Sync Event Notifier

class SyncEventNotifier: ObservableObject {
    
    @Published var lastEvent: SyncEvent?
    @Published var isSyncing = false
    @Published var lastError: Error?
    
    private let syncService = MonitoredBackgroundSyncService()
    private var subscriptionId: UUID?
    
    init() {
        subscriptionId = syncService.subscribeToEvents { [weak self] event in
            DispatchQueue.main.async {
                self?.handleEvent(event)
            }
        }
    }
    
    deinit {
        if let id = subscriptionId {
            syncService.unsubscribe(id: id)
        }
    }
    
    private func handleEvent(_ event: SyncEvent) {
        lastEvent = event
        
        switch event {
        case .syncStarted:
            isSyncing = true
            lastError = nil
        case .syncCompleted:
            isSyncing = false
        case .syncFailed(let error):
            isSyncing = false
            lastError = error
        default:
            break
        }
    }
    
    func forceSync() async {
        do {
            try await syncService.forceSync()
        } catch {
            lastError = error
        }
    }
}

// MARK: - Background Sync Debug View

@MainActor
class SyncDebugViewController: UIViewController {
    
    private let eventNotifier = SyncEventNotifier()
    private let textView = UITextView()
    private let refreshButton = UIButton(type: .system)
    private var cancellables = Set<AnyCancellable>()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }
    
    private func setupUI() {
        title = "Sync Debug"
        view.backgroundColor = .systemBackground
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.isEditable = false
        view.addSubview(textView)
        
        refreshButton.setTitle("Refresh", for: .normal)
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: refreshButton)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupBindings() {
        eventNotifier.$lastEvent
            .sink { [weak self] event in
                self?.updateDebugInfo()
            }
            .store(in: &cancellables)
        
        eventNotifier.$isSyncing
            .sink { [weak self] isSyncing in
                self?.refreshButton.isEnabled = !isSyncing
            }
            .store(in: &cancellables)
    }
    
    @objc private func refreshTapped() {
        updateDebugInfo()
    }
    
    private func updateDebugInfo() {
        Task {
            let debugInfo = await BackgroundSyncDebugger.shared.getDebugInfo()
            textView.text = debugInfo
        }
    }
}
