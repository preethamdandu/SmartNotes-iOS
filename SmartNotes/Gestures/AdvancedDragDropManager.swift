import UIKit
import os.log

// MARK: - Advanced Drag and Drop Manager

class AdvancedDragDropManager: NSObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.apple.smartnotes", category: "drag.drop")
    private weak var collectionView: UICollectionView?
    private weak var viewController: UIViewController?
    
    // Drag and drop state
    private var draggedIndexPath: IndexPath?
    private var dragPreviewProvider: DragPreviewProvider?
    private var dropProposalProvider: DropProposalProvider?
    
    // Device-specific configuration
    private let deviceIdiom = UIDevice.current.userInterfaceIdiom
    private let isIPad = UIDevice.current.userInterfaceIdiom == .pad
    
    // Animation configuration
    private let dragAnimationDuration: TimeInterval = 0.3
    private let dropAnimationDuration: TimeInterval = 0.2
    private let springDamping: CGFloat = 0.8
    private let springVelocity: CGFloat = 0.5
    
    // MARK: - Initialization
    
    init(collectionView: UICollectionView, viewController: UIViewController) {
        self.collectionView = collectionView
        self.viewController = viewController
        super.init()
        
        setupDragAndDrop()
    }
    
    // MARK: - Setup
    
    private func setupDragAndDrop() {
        guard let collectionView = collectionView else { return }
        
        // Configure drag and drop delegates
        collectionView.dragDelegate = self
        collectionView.dropDelegate = self
        
        // Enable drag interaction
        collectionView.dragInteractionEnabled = true
        
        // Configure based on device type
        if isIPad {
            setupiPadDragAndDrop()
        } else {
            setupiPhoneDragAndDrop()
        }
        
        logger.info("Drag and drop configured for \(isIPad ? "iPad" : "iPhone")")
    }
    
    private func setupiPadDragAndDrop() {
        // iPad gets full drag and drop capabilities
        guard let collectionView = collectionView else { return }
        
        // Enable reordering
        collectionView.reorderingCadence = .immediate
        
        // Configure for multi-window support
        if #available(iOS 13.0, *) {
            collectionView.dragInteractionEnabled = true
        }
        
        logger.info("iPad drag and drop configured with full capabilities")
    }
    
    private func setupiPhoneDragAndDrop() {
        // iPhone gets limited drag and drop with haptic feedback
        guard let collectionView = collectionView else { return }
        
        // Enable reordering with slower cadence for better UX
        collectionView.reorderingCadence = .slow
        
        logger.info("iPhone drag and drop configured with limited capabilities")
    }
    
    // MARK: - Configuration
    
    func setDragPreviewProvider(_ provider: DragPreviewProvider) {
        self.dragPreviewProvider = provider
    }
    
    func setDropProposalProvider(_ provider: DropProposalProvider) {
        self.dropProposalProvider = provider
    }
    
    // MARK: - Helper Methods
    
    private func createDragPreview(for item: UIDragItem) -> UIDragPreview? {
        guard let dragPreviewProvider = dragPreviewProvider else {
            return createDefaultDragPreview(for: item)
        }
        
        return dragPreviewProvider.createDragPreview(for: item)
    }
    
    private func createDefaultDragPreview(for item: UIDragItem) -> UIDragPreview? {
        guard let indexPath = item.localObject as? IndexPath,
              let collectionView = collectionView,
              let cell = collectionView.cellForItem(at: indexPath) else {
            return nil
        }
        
        // Create a snapshot of the cell
        let snapshot = cell.snapshotView(afterScreenUpdates: false)
        snapshot?.frame = cell.frame
        
        // Configure the preview
        let preview = UIDragPreview(view: snapshot ?? cell)
        preview.parameters = UIDragPreviewParameters()
        preview.parameters.backgroundColor = .clear
        
        return preview
    }
    
    private func createDropProposal(for session: UIDropSession) -> UICollectionViewDropProposal {
        guard let dropProposalProvider = dropProposalProvider else {
            return createDefaultDropProposal(for: session)
        }
        
        return dropProposalProvider.createDropProposal(for: session)
    }
    
    private func createDefaultDropProposal(for session: UIDropSession) -> UICollectionViewDropProposal {
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
    
    // MARK: - Animation Helpers
    
    private func animateDragStart(for cell: UICollectionViewCell) {
        UIView.animate(withDuration: dragAnimationDuration, delay: 0, usingSpringWithDamping: springDamping, initialSpringVelocity: springVelocity, options: [.allowUserInteraction, .beginFromCurrentState]) {
            cell.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
            cell.alpha = 0.8
        }
    }
    
    private func animateDragEnd(for cell: UICollectionViewCell) {
        UIView.animate(withDuration: dragAnimationDuration, delay: 0, usingSpringWithDamping: springDamping, initialSpringVelocity: springVelocity, options: [.allowUserInteraction, .beginFromCurrentState]) {
            cell.transform = .identity
            cell.alpha = 1.0
        }
    }
    
    private func animateDrop(at indexPath: IndexPath) {
        guard let collectionView = collectionView,
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        // Flash animation for successful drop
        UIView.animate(withDuration: 0.1, animations: {
            cell.backgroundColor = .systemBlue.withAlphaComponent(0.3)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                cell.backgroundColor = .systemBackground
            }
        }
    }
    
    // MARK: - Haptic Feedback
    
    private func provideHapticFeedback(for event: DragDropEvent) {
        let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        
        switch event {
        case .dragStarted:
            feedbackGenerator.impactOccurred()
        case .dropCompleted:
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.notificationOccurred(.success)
        case .dropFailed:
            let errorGenerator = UINotificationFeedbackGenerator()
            errorGenerator.notificationOccurred(.error)
        case .reorderCompleted:
            feedbackGenerator.impactOccurred()
        }
    }
}

// MARK: - Drag and Drop Delegates

extension AdvancedDragDropManager: UICollectionViewDragDelegate {
    
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        logger.debug("Drag session began at indexPath: \(indexPath)")
        
        // Store the dragged index path
        draggedIndexPath = indexPath
        
        // Create drag item
        let dragItem = createDragItem(for: indexPath)
        
        // Provide haptic feedback
        provideHapticFeedback(for: .dragStarted)
        
        // Animate the dragged cell
        if let cell = collectionView.cellForItem(at: indexPath) {
            animateDragStart(for: cell)
        }
        
        return [dragItem]
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        
        // Configure shadow for better visual feedback
        if let cell = collectionView.cellForItem(at: indexPath) {
            parameters.visiblePath = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 12)
        }
        
        return parameters
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        logger.debug("Drag session ended")
        
        // Reset dragged index path
        draggedIndexPath = nil
        
        // Animate all cells back to normal
        for indexPath in collectionView.indexPathsForVisibleItems {
            if let cell = collectionView.cellForItem(at: indexPath) {
                animateDragEnd(for: cell)
            }
        }
    }
    
    private func createDragItem(for indexPath: IndexPath) -> UIDragItem {
        // Create a drag item with the index path as local object
        let itemProvider = NSItemProvider()
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = indexPath
        
        return dragItem
    }
}

extension AdvancedDragDropManager: UICollectionViewDropDelegate {
    
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool {
        // Allow drops from local drag sessions or external sources
        return session.canLoadObjects(ofClass: NSString.self) || session.localDragSession != nil
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal {
        logger.debug("Drop session updated with destination: \(destinationIndexPath?.description ?? "nil")")
        
        return createDropProposal(for: session)
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        logger.debug("Performing drop with coordinator")
        
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
            logger.warning("No destination index path for drop")
            provideHapticFeedback(for: .dropFailed)
            return
        }
        
        // Handle different types of drops
        for item in coordinator.items {
            if item.sourceIndexPath != nil {
                // Local reordering
                handleLocalReorder(item: item, destinationIndexPath: destinationIndexPath, coordinator: coordinator)
            } else {
                // External drop
                handleExternalDrop(item: item, destinationIndexPath: destinationIndexPath, coordinator: coordinator)
            }
        }
    }
    
    private func handleLocalReorder(item: UICollectionViewDropItem, destinationIndexPath: IndexPath, coordinator: UICollectionViewDropCoordinator) {
        guard let sourceIndexPath = item.sourceIndexPath else { return }
        
        logger.debug("Handling local reorder from \(sourceIndexPath) to \(destinationIndexPath)")
        
        // Perform the reorder
        coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)
        
        // Animate the drop
        animateDrop(at: destinationIndexPath)
        
        // Provide haptic feedback
        provideHapticFeedback(for: .reorderCompleted)
        
        // Notify delegate if needed
        notifyReorderCompleted(from: sourceIndexPath, to: destinationIndexPath)
    }
    
    private func handleExternalDrop(item: UICollectionViewDropItem, destinationIndexPath: IndexPath, coordinator: UICollectionViewDropCoordinator) {
        logger.debug("Handling external drop at \(destinationIndexPath)")
        
        // Load the dropped content
        item.dragItem.itemProvider.loadObject(ofClass: NSString.self) { [weak self] (data, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.logger.error("Failed to load dropped content: \(error.localizedDescription)")
                    self?.provideHapticFeedback(for: .dropFailed)
                    return
                }
                
                // Handle the dropped content
                self?.handleDroppedContent(data, at: destinationIndexPath)
                
                // Animate the drop
                self?.animateDrop(at: destinationIndexPath)
                
                // Provide haptic feedback
                self?.provideHapticFeedback(for: .dropCompleted)
            }
        }
    }
    
    private func handleDroppedContent(_ content: Any?, at indexPath: IndexPath) {
        // Implement specific handling for dropped content
        logger.debug("Handling dropped content at \(indexPath)")
        
        // This would be implemented based on your specific needs
        // For example, creating a new note from dropped text
    }
    
    private func notifyReorderCompleted(from sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        // Notify the view controller about the reorder
        // This would typically update the data source
        logger.debug("Reorder completed from \(sourceIndexPath) to \(destinationIndexPath)")
    }
}

// MARK: - Supporting Types

enum DragDropEvent {
    case dragStarted
    case dropCompleted
    case dropFailed
    case reorderCompleted
}

protocol DragPreviewProvider {
    func createDragPreview(for item: UIDragItem) -> UIDragPreview?
}

protocol DropProposalProvider {
    func createDropProposal(for session: UIDropSession) -> UICollectionViewDropProposal
}

// MARK: - Device-Specific Drag and Drop Extensions

extension AdvancedDragDropManager {
    
    // MARK: - iPad-Specific Features
    
    func configureForMultiWindow() {
        guard isIPad else { return }
        
        // Configure for multi-window drag and drop
        if #available(iOS 13.0, *) {
            collectionView?.dragInteractionEnabled = true
        }
        
        logger.info("Multi-window drag and drop configured")
    }
    
    func configureForSplitView() {
        guard isIPad else { return }
        
        // Configure for split view drag and drop
        // This would include handling drops between different panes
        
        logger.info("Split view drag and drop configured")
    }
    
    // MARK: - iPhone-Specific Features
    
    func configureForCompactLayout() {
        guard !isIPad else { return }
        
        // Configure for compact layout drag and drop
        // This might include different animation timings or gesture recognition
        
        logger.info("Compact layout drag and drop configured")
    }
    
    func configureForOneHandedUse() {
        guard !isIPad else { return }
        
        // Configure for one-handed use
        // This might include different drag thresholds or gesture areas
        
        logger.info("One-handed drag and drop configured")
    }
}

// MARK: - Gesture Recognition Extensions

extension AdvancedDragDropManager {
    
    func addLongPressGestureRecognizer() {
        guard let collectionView = collectionView else { return }
        
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        collectionView.addGestureRecognizer(longPressGesture)
        
        logger.info("Long press gesture recognizer added")
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let collectionView = collectionView else { return }
        
        let location = gesture.location(in: collectionView)
        
        switch gesture.state {
        case .began:
            if let indexPath = collectionView.indexPathForItem(at: location) {
                // Start drag session programmatically
                startDragSession(at: indexPath)
            }
        case .changed:
            // Handle gesture changes
            break
        case .ended, .cancelled:
            // Handle gesture end
            break
        default:
            break
        }
    }
    
    private func startDragSession(at indexPath: IndexPath) {
        guard let collectionView = collectionView else { return }
        
        // Create drag session
        let dragItem = createDragItem(for: indexPath)
        let dragSession = collectionView.beginInteractiveMovement(forItemAt: indexPath)
        
        logger.debug("Started interactive movement for indexPath: \(indexPath)")
    }
}

// MARK: - UIGestureRecognizerDelegate

extension AdvancedDragDropManager: UIGestureRecognizerDelegate {
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow simultaneous recognition with collection view gestures
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Require failure of certain gestures to prevent conflicts
        return false
    }
}
