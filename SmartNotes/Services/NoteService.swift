import Foundation
import CoreData
import Combine

// MARK: - Core Data Stack

class CoreDataStack {
    static let shared = CoreDataStack()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "SmartNotesModel")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }
        
        // Enable CloudKit integration
        container.persistentStoreDescriptions.forEach { storeDescription in
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Core Data save error: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Core Data Entities

@objc(NoteEntity)
public class NoteEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var content: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var tags: [String]
    @NSManaged public var isEncrypted: Bool
    @NSManaged public var isPinned: Bool
    @NSManaged public var colorRawValue: String
    @NSManaged public var syncStatus: String
    @NSManaged public var lastSyncAt: Date?
}

extension NoteEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<NoteEntity> {
        return NSFetchRequest<NoteEntity>(entityName: "NoteEntity")
    }
    
    var color: NoteColor {
        get { NoteColor(rawValue: colorRawValue) ?? .default }
        set { colorRawValue = newValue.rawValue }
    }
    
    var syncStatusEnum: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .synced }
        set { syncStatus = newValue.rawValue }
    }
}

enum SyncStatus: String, CaseIterable {
    case synced = "synced"
    case pending = "pending"
    case conflict = "conflict"
    case error = "error"
}

// MARK: - Note Service Implementation

class NoteService: NoteServiceProtocol {
    private let coreDataStack = CoreDataStack.shared
    private let encryptionService = EncryptionService()
    
    func fetchAllNotes() async throws -> [Note] {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let request: NSFetchRequest<NoteEntity> = NoteEntity.fetchRequest()
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
    
    func saveNote(_ note: Note) async throws -> Note {
        return try await withCheckedThrowingContinuation { continuation in
            let context = coreDataStack.context
            context.perform {
                do {
                    let entity = NoteEntity(context: context)
                    self.populateEntity(entity, with: note)
                    
                    try context.save()
                    coreDataStack.saveContext()
                    
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
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func searchNotes(query: String) async throws -> [Note] {
        return try await withCheckedThrowingContinuation { continuation in
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

// MARK: - Errors

enum NoteServiceError: Error, LocalizedError {
    case noteNotFound
    case encryptionFailed
    case decryptionFailed
    case coreDataError(String)
    
    var errorDescription: String? {
        switch self {
        case .noteNotFound:
            return "Note not found"
        case .encryptionFailed:
            return "Failed to encrypt note"
        case .decryptionFailed:
            return "Failed to decrypt note"
        case .coreDataError(let message):
            return "Core Data error: \(message)"
        }
    }
}
