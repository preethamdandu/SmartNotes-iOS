import XCTest
import CoreData
import Combine
@testable import SmartNotes

// MARK: - Note CRUD Unit Tests

class NoteCRUDTests: XCTestCase {
    
    // MARK: - Properties
    
    var noteService: NoteServiceProtocol!
    var mockCoreDataStack: MockCoreDataStack!
    var mockEncryptionService: MockEncryptionService!
    var mockAPIClient: MockAPIClient!
    var cancellables: Set<AnyCancellable>!
    
    // Test data
    var testNote: Note!
    var testNotes: [Note]!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Initialize mocks
        mockCoreDataStack = MockCoreDataStack()
        mockEncryptionService = MockEncryptionService()
        mockAPIClient = MockAPIClient()
        cancellables = Set<AnyCancellable>()
        
        // Initialize service with mocks
        noteService = NoteService(
            coreDataStack: mockCoreDataStack,
            encryptionService: mockEncryptionService,
            apiClient: mockAPIClient
        )
        
        // Create test data
        setupTestData()
    }
    
    override func tearDown() {
        noteService = nil
        mockCoreDataStack = nil
        mockEncryptionService = nil
        mockAPIClient = nil
        cancellables = nil
        testNote = nil
        testNotes = nil
        super.tearDown()
    }
    
    private func setupTestData() {
        testNote = Note(
            title: "Test Note",
            content: "This is test content",
            tags: ["test", "unit"],
            color: .blue
        )
        
        testNotes = [
            Note(title: "Note 1", content: "Content 1", tags: ["work"], color: .green),
            Note(title: "Note 2", content: "Content 2", tags: ["personal"], color: .yellow),
            Note(title: "Note 3", content: "Content 3", tags: ["work", "urgent"], color: .red)
        ]
    }
    
    // MARK: - Create Note Tests
    
    func testCreateNote_Success() async throws {
        // Given
        let newNote = Note(title: "New Note", content: "New content", tags: ["new"], color: .purple)
        mockCoreDataStack.mockSaveResult = .success(newNote)
        
        // When
        let result = try await noteService.saveNote(newNote)
        
        // Then
        XCTAssertEqual(result.title, "New Note")
        XCTAssertEqual(result.content, "New content")
        XCTAssertEqual(result.tags, ["new"])
        XCTAssertEqual(result.color, .purple)
        XCTAssertNotNil(result.id)
        XCTAssertNotNil(result.createdAt)
        XCTAssertNotNil(result.updatedAt)
        XCTAssertTrue(mockCoreDataStack.saveNoteCalled)
    }
    
    func testCreateNote_WithEmptyTitle() async throws {
        // Given
        let noteWithEmptyTitle = Note(title: "", content: "Content", tags: [], color: .default)
        
        // When & Then
        do {
            _ = try await noteService.saveNote(noteWithEmptyTitle)
            XCTFail("Should throw validation error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.validationFailed(let message) = error {
                XCTAssertTrue(message.contains("title"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testCreateNote_WithEmptyContent() async throws {
        // Given
        let noteWithEmptyContent = Note(title: "Title", content: "", tags: [], color: .default)
        
        // When & Then
        do {
            _ = try await noteService.saveNote(noteWithEmptyContent)
            XCTFail("Should throw validation error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.validationFailed(let message) = error {
                XCTAssertTrue(message.contains("content"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testCreateNote_WithVeryLongTitle() async throws {
        // Given
        let longTitle = String(repeating: "A", count: 1001) // Exceeds limit
        let noteWithLongTitle = Note(title: longTitle, content: "Content", tags: [], color: .default)
        
        // When & Then
        do {
            _ = try await noteService.saveNote(noteWithLongTitle)
            XCTFail("Should throw validation error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.validationFailed(let message) = error {
                XCTAssertTrue(message.contains("title"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testCreateNote_WithVeryLongContent() async throws {
        // Given
        let longContent = String(repeating: "B", count: 10001) // Exceeds limit
        let noteWithLongContent = Note(title: "Title", content: longContent, tags: [], color: .default)
        
        // When & Then
        do {
            _ = try await noteService.saveNote(noteWithLongContent)
            XCTFail("Should throw validation error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.validationFailed(let message) = error {
                XCTAssertTrue(message.contains("content"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testCreateNote_WithManyTags() async throws {
        // Given
        let manyTags = (1...51).map { "tag\($0)" } // Exceeds limit
        let noteWithManyTags = Note(title: "Title", content: "Content", tags: manyTags, color: .default)
        
        // When & Then
        do {
            _ = try await noteService.saveNote(noteWithManyTags)
            XCTFail("Should throw validation error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.validationFailed(let message) = error {
                XCTAssertTrue(message.contains("tags"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testCreateNote_WithSpecialCharacters() async throws {
        // Given
        let noteWithSpecialChars = Note(
            title: "Title with émojis 🚀 and spëcial chars",
            content: "Content with\nnewlines\tand\ttabs",
            tags: ["tag-with-dashes", "tag_with_underscores"],
            color: .default
        )
        mockCoreDataStack.mockSaveResult = .success(noteWithSpecialChars)
        
        // When
        let result = try await noteService.saveNote(noteWithSpecialChars)
        
        // Then
        XCTAssertEqual(result.title, "Title with émojis 🚀 and spëcial chars")
        XCTAssertEqual(result.content, "Content with\nnewlines\tand\ttabs")
        XCTAssertEqual(result.tags, ["tag-with-dashes", "tag_with_underscores"])
    }
    
    func testCreateNote_WithEncryption() async throws {
        // Given
        var encryptedNote = Note(title: "Secret Note", content: "Secret content", tags: [], color: .default)
        encryptedNote.isEncrypted = true
        mockCoreDataStack.mockSaveResult = .success(encryptedNote)
        mockEncryptionService.mockEncryptResult = .success(Data("encrypted".utf8))
        
        // When
        let result = try await noteService.saveNote(encryptedNote)
        
        // Then
        XCTAssertTrue(result.isEncrypted)
        XCTAssertTrue(mockEncryptionService.encryptNoteCalled)
    }
    
    func testCreateNote_CoreDataError() async throws {
        // Given
        let newNote = Note(title: "New Note", content: "New content", tags: [], color: .default)
        mockCoreDataStack.mockSaveResult = .failure(CoreDataError.saveFailed)
        
        // When & Then
        do {
            _ = try await noteService.saveNote(newNote)
            XCTFail("Should throw Core Data error")
        } catch {
            XCTAssertTrue(error is CoreDataError)
        }
    }
    
    func testCreateNote_EncryptionError() async throws {
        // Given
        var encryptedNote = Note(title: "Secret Note", content: "Secret content", tags: [], color: .default)
        encryptedNote.isEncrypted = true
        mockEncryptionService.mockEncryptResult = .failure(EncryptionError.encryptionFailed)
        
        // When & Then
        do {
            _ = try await noteService.saveNote(encryptedNote)
            XCTFail("Should throw encryption error")
        } catch {
            XCTAssertTrue(error is EncryptionError)
        }
    }
    
    // MARK: - Read Note Tests
    
    func testFetchAllNotes_Success() async throws {
        // Given
        mockCoreDataStack.mockNotes = testNotes
        
        // When
        let result = try await noteService.fetchAllNotes()
        
        // Then
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].title, "Note 1")
        XCTAssertEqual(result[1].title, "Note 2")
        XCTAssertEqual(result[2].title, "Note 3")
        XCTAssertTrue(mockCoreDataStack.fetchAllNotesCalled)
    }
    
    func testFetchAllNotes_EmptyResult() async throws {
        // Given
        mockCoreDataStack.mockNotes = []
        
        // When
        let result = try await noteService.fetchAllNotes()
        
        // Then
        XCTAssertEqual(result.count, 0)
        XCTAssertTrue(mockCoreDataStack.fetchAllNotesCalled)
    }
    
    func testFetchAllNotes_CoreDataError() async throws {
        // Given
        mockCoreDataStack.mockFetchError = CoreDataError.fetchFailed
        
        // When & Then
        do {
            _ = try await noteService.fetchAllNotes()
            XCTFail("Should throw Core Data error")
        } catch {
            XCTAssertTrue(error is CoreDataError)
        }
    }
    
    func testFetchNote_ById_Success() async throws {
        // Given
        let noteId = testNote.id
        mockCoreDataStack.mockNoteById = testNote
        
        // When
        let result = try await noteService.fetchNote(id: noteId)
        
        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.id, noteId)
        XCTAssertEqual(result?.title, "Test Note")
        XCTAssertTrue(mockCoreDataStack.fetchNoteByIdCalled)
    }
    
    func testFetchNote_ById_NotFound() async throws {
        // Given
        let nonExistentId = UUID()
        mockCoreDataStack.mockNoteById = nil
        
        // When
        let result = try await noteService.fetchNote(id: nonExistentId)
        
        // Then
        XCTAssertNil(result)
        XCTAssertTrue(mockCoreDataStack.fetchNoteByIdCalled)
    }
    
    func testFetchNote_ById_CoreDataError() async throws {
        // Given
        let noteId = testNote.id
        mockCoreDataStack.mockFetchError = CoreDataError.fetchFailed
        
        // When & Then
        do {
            _ = try await noteService.fetchNote(id: noteId)
            XCTFail("Should throw Core Data error")
        } catch {
            XCTAssertTrue(error is CoreDataError)
        }
    }
    
    func testSearchNotes_Success() async throws {
        // Given
        let searchQuery = "work"
        mockCoreDataStack.mockSearchResults = [testNotes[0], testNotes[2]] // Notes with "work" tag
        
        // When
        let result = try await noteService.searchNotes(query: searchQuery)
        
        // Then
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.allSatisfy { $0.tags.contains("work") })
        XCTAssertTrue(mockCoreDataStack.searchNotesCalled)
        XCTAssertEqual(mockCoreDataStack.lastSearchQuery, searchQuery)
    }
    
    func testSearchNotes_EmptyQuery() async throws {
        // Given
        let emptyQuery = ""
        
        // When & Then
        do {
            _ = try await noteService.searchNotes(query: emptyQuery)
            XCTFail("Should throw validation error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.validationFailed(let message) = error {
                XCTAssertTrue(message.contains("query"))
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testSearchNotes_SpecialCharacters() async throws {
        // Given
        let specialQuery = "test@#$%^&*()"
        mockCoreDataStack.mockSearchResults = []
        
        // When
        let result = try await noteService.searchNotes(query: specialQuery)
        
        // Then
        XCTAssertEqual(result.count, 0)
        XCTAssertTrue(mockCoreDataStack.searchNotesCalled)
    }
    
    // MARK: - Update Note Tests
    
    func testUpdateNote_Success() async throws {
        // Given
        var updatedNote = testNote
        updatedNote.title = "Updated Title"
        updatedNote.content = "Updated content"
        updatedNote.tags = ["updated", "test"]
        updatedNote.color = .green
        
        mockCoreDataStack.mockNoteById = testNote
        mockCoreDataStack.mockUpdateResult = .success(updatedNote)
        
        // When
        let result = try await noteService.updateNote(updatedNote)
        
        // Then
        XCTAssertEqual(result.title, "Updated Title")
        XCTAssertEqual(result.content, "Updated content")
        XCTAssertEqual(result.tags, ["updated", "test"])
        XCTAssertEqual(result.color, .green)
        XCTAssertTrue(mockCoreDataStack.updateNoteCalled)
    }
    
    func testUpdateNote_NotFound() async throws {
        // Given
        var updatedNote = testNote
        updatedNote.title = "Updated Title"
        mockCoreDataStack.mockNoteById = nil
        
        // When & Then
        do {
            _ = try await noteService.updateNote(updatedNote)
            XCTFail("Should throw not found error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.noteNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected note not found error")
            }
        }
    }
    
    func testUpdateNote_WithInvalidData() async throws {
        // Given
        var invalidNote = testNote
        invalidNote.title = "" // Invalid title
        mockCoreDataStack.mockNoteById = testNote
        
        // When & Then
        do {
            _ = try await noteService.updateNote(invalidNote)
            XCTFail("Should throw validation error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.validationFailed = error {
                // Expected error
            } else {
                XCTFail("Expected validation error")
            }
        }
    }
    
    func testUpdateNote_ConcurrentModification() async throws {
        // Given
        var updatedNote = testNote
        updatedNote.title = "Updated Title"
        mockCoreDataStack.mockNoteById = testNote
        mockCoreDataStack.mockUpdateResult = .failure(CoreDataError.concurrentModification)
        
        // When & Then
        do {
            _ = try await noteService.updateNote(updatedNote)
            XCTFail("Should throw concurrent modification error")
        } catch {
            XCTAssertTrue(error is CoreDataError)
        }
    }
    
    func testUpdateNote_EncryptionChange() async throws {
        // Given
        var encryptedNote = testNote
        encryptedNote.isEncrypted = true
        mockCoreDataStack.mockNoteById = testNote
        mockCoreDataStack.mockUpdateResult = .success(encryptedNote)
        mockEncryptionService.mockEncryptResult = .success(Data("encrypted".utf8))
        
        // When
        let result = try await noteService.updateNote(encryptedNote)
        
        // Then
        XCTAssertTrue(result.isEncrypted)
        XCTAssertTrue(mockEncryptionService.encryptNoteCalled)
    }
    
    // MARK: - Delete Note Tests
    
    func testDeleteNote_Success() async throws {
        // Given
        let noteId = testNote.id
        mockCoreDataStack.mockNoteById = testNote
        mockCoreDataStack.mockDeleteResult = .success(())
        
        // When
        try await noteService.deleteNote(id: noteId)
        
        // Then
        XCTAssertTrue(mockCoreDataStack.deleteNoteCalled)
        XCTAssertEqual(mockCoreDataStack.deletedNoteId, noteId)
    }
    
    func testDeleteNote_NotFound() async throws {
        // Given
        let nonExistentId = UUID()
        mockCoreDataStack.mockNoteById = nil
        
        // When & Then
        do {
            try await noteService.deleteNote(id: nonExistentId)
            XCTFail("Should throw not found error")
        } catch {
            XCTAssertTrue(error is NoteServiceError)
            if case NoteServiceError.noteNotFound = error {
                // Expected error
            } else {
                XCTFail("Expected note not found error")
            }
        }
    }
    
    func testDeleteNote_CoreDataError() async throws {
        // Given
        let noteId = testNote.id
        mockCoreDataStack.mockNoteById = testNote
        mockCoreDataStack.mockDeleteResult = .failure(CoreDataError.deleteFailed)
        
        // When & Then
        do {
            try await noteService.deleteNote(id: noteId)
            XCTFail("Should throw Core Data error")
        } catch {
            XCTAssertTrue(error is CoreDataError)
        }
    }
    
    func testDeleteNote_EncryptedNote() async throws {
        // Given
        var encryptedNote = testNote
        encryptedNote.isEncrypted = true
        let noteId = encryptedNote.id
        mockCoreDataStack.mockNoteById = encryptedNote
        mockCoreDataStack.mockDeleteResult = .success(())
        mockEncryptionService.mockDecryptResult = .success(encryptedNote)
        
        // When
        try await noteService.deleteNote(id: noteId)
        
        // Then
        XCTAssertTrue(mockCoreDataStack.deleteNoteCalled)
        XCTAssertTrue(mockEncryptionService.decryptNoteCalled)
    }
    
    // MARK: - Batch Operations Tests
    
    func testBatchCreateNotes_Success() async throws {
        // Given
        let notesToCreate = testNotes
        mockCoreDataStack.mockBatchSaveResult = .success(notesToCreate)
        
        // When
        let result = try await noteService.batchSaveNotes(notesToCreate)
        
        // Then
        XCTAssertEqual(result.count, 3)
        XCTAssertTrue(mockCoreDataStack.batchSaveNotesCalled)
    }
    
    func testBatchCreateNotes_PartialFailure() async throws {
        // Given
        let notesToCreate = testNotes
        mockCoreDataStack.mockBatchSaveResult = .failure(CoreDataError.batchSavePartialFailure)
        
        // When & Then
        do {
            _ = try await noteService.batchSaveNotes(notesToCreate)
            XCTFail("Should throw batch save error")
        } catch {
            XCTAssertTrue(error is CoreDataError)
        }
    }
    
    func testBatchDeleteNotes_Success() async throws {
        // Given
        let noteIds = testNotes.map { $0.id }
        mockCoreDataStack.mockBatchDeleteResult = .success(())
        
        // When
        try await noteService.batchDeleteNotes(ids: noteIds)
        
        // Then
        XCTAssertTrue(mockCoreDataStack.batchDeleteNotesCalled)
        XCTAssertEqual(mockCoreDataStack.batchDeletedIds, noteIds)
    }
    
    func testBatchDeleteNotes_PartialFailure() async throws {
        // Given
        let noteIds = testNotes.map { $0.id }
        mockCoreDataStack.mockBatchDeleteResult = .failure(CoreDataError.batchDeletePartialFailure)
        
        // When & Then
        do {
            try await noteService.batchDeleteNotes(ids: noteIds)
            XCTFail("Should throw batch delete error")
        } catch {
            XCTAssertTrue(error is CoreDataError)
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testConcurrentOperations() async throws {
        // Given
        let note1 = Note(title: "Note 1", content: "Content 1", tags: [], color: .default)
        let note2 = Note(title: "Note 2", content: "Content 2", tags: [], color: .default)
        
        mockCoreDataStack.mockSaveResult = .success(note1)
        mockCoreDataStack.mockNotes = [note1, note2]
        
        // When - Perform concurrent operations
        async let createResult = noteService.saveNote(note1)
        async let fetchResult = noteService.fetchAllNotes()
        
        let (savedNote, fetchedNotes) = try await (createResult, fetchResult)
        
        // Then
        XCTAssertEqual(savedNote.title, "Note 1")
        XCTAssertEqual(fetchedNotes.count, 2)
    }
    
    func testMemoryPressureHandling() async throws {
        // Given
        let largeNotes = (1...1000).map { i in
            Note(title: "Note \(i)", content: "Content \(i)", tags: [], color: .default)
        }
        mockCoreDataStack.mockNotes = largeNotes
        
        // When
        let result = try await noteService.fetchAllNotes()
        
        // Then
        XCTAssertEqual(result.count, 1000)
        // Verify memory management is working
        XCTAssertTrue(mockCoreDataStack.fetchAllNotesCalled)
    }
    
    func testNetworkFailureFallback() async throws {
        // Given
        mockAPIClient.mockNetworkError = NetworkError.noConnection
        mockCoreDataStack.mockNotes = testNotes
        
        // When
        let result = try await noteService.fetchAllNotes()
        
        // Then
        XCTAssertEqual(result.count, 3)
        // Should fallback to local data
        XCTAssertTrue(mockCoreDataStack.fetchAllNotesCalled)
    }
    
    func testDataCorruptionHandling() async throws {
        // Given
        mockCoreDataStack.mockCorruptedData = true
        
        // When & Then
        do {
            _ = try await noteService.fetchAllNotes()
            XCTFail("Should throw data corruption error")
        } catch {
            XCTAssertTrue(error is CoreDataError)
            if case CoreDataError.dataCorruption = error {
                // Expected error
            } else {
                XCTFail("Expected data corruption error")
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_FetchLargeDataset() {
        // Given
        let largeNotes = (1...10000).map { i in
            Note(title: "Note \(i)", content: "Content \(i)", tags: [], color: .default)
        }
        mockCoreDataStack.mockNotes = largeNotes
        
        // When & Then
        measure {
            let expectation = XCTestExpectation(description: "Fetch large dataset")
            
            Task {
                do {
                    let result = try await noteService.fetchAllNotes()
                    XCTAssertEqual(result.count, 10000)
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPerformance_BatchOperations() {
        // Given
        let batchNotes = (1...1000).map { i in
            Note(title: "Note \(i)", content: "Content \(i)", tags: [], color: .default)
        }
        mockCoreDataStack.mockBatchSaveResult = .success(batchNotes)
        
        // When & Then
        measure {
            let expectation = XCTestExpectation(description: "Batch operations")
            
            Task {
                do {
                    let result = try await noteService.batchSaveNotes(batchNotes)
                    XCTAssertEqual(result.count, 1000)
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
}

// MARK: - Mock Implementations

class MockCoreDataStack: CoreDataStackProtocol {
    var mockNotes: [Note] = []
    var mockNoteById: Note?
    var mockSearchResults: [Note] = []
    var mockSaveResult: Result<Note, Error> = .success(Note(title: "Mock", content: "Mock"))
    var mockUpdateResult: Result<Note, Error> = .success(Note(title: "Mock", content: "Mock"))
    var mockDeleteResult: Result<Void, Error> = .success(())
    var mockBatchSaveResult: Result<[Note], Error> = .success([])
    var mockBatchDeleteResult: Result<Void, Error> = .success(())
    
    var mockFetchError: Error?
    var mockCorruptedData = false
    
    var fetchAllNotesCalled = false
    var fetchNoteByIdCalled = false
    var saveNoteCalled = false
    var updateNoteCalled = false
    var deleteNoteCalled = false
    var searchNotesCalled = false
    var batchSaveNotesCalled = false
    var batchDeleteNotesCalled = false
    
    var deletedNoteId: UUID?
    var lastSearchQuery: String?
    var batchDeletedIds: [UUID] = []
    
    func fetchAllNotes() async throws -> [Note] {
        fetchAllNotesCalled = true
        
        if let error = mockFetchError {
            throw error
        }
        
        if mockCorruptedData {
            throw CoreDataError.dataCorruption
        }
        
        return mockNotes
    }
    
    func fetchNote(id: UUID) async throws -> Note? {
        fetchNoteByIdCalled = true
        
        if let error = mockFetchError {
            throw error
        }
        
        return mockNoteById
    }
    
    func saveNote(_ note: Note) async throws -> Note {
        saveNoteCalled = true
        
        switch mockSaveResult {
        case .success(let savedNote):
            return savedNote
        case .failure(let error):
            throw error
        }
    }
    
    func updateNote(_ note: Note) async throws -> Note {
        updateNoteCalled = true
        
        switch mockUpdateResult {
        case .success(let updatedNote):
            return updatedNote
        case .failure(let error):
            throw error
        }
    }
    
    func deleteNote(id: UUID) async throws {
        deleteNoteCalled = true
        deletedNoteId = id
        
        switch mockDeleteResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    func searchNotes(query: String) async throws -> [Note] {
        searchNotesCalled = true
        lastSearchQuery = query
        
        if let error = mockFetchError {
            throw error
        }
        
        return mockSearchResults
    }
    
    func batchSaveNotes(_ notes: [Note]) async throws -> [Note] {
        batchSaveNotesCalled = true
        
        switch mockBatchSaveResult {
        case .success(let savedNotes):
            return savedNotes
        case .failure(let error):
            throw error
        }
    }
    
    func batchDeleteNotes(ids: [UUID]) async throws {
        batchDeleteNotesCalled = true
        batchDeletedIds = ids
        
        switch mockBatchDeleteResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

class MockEncryptionService: EncryptionServiceProtocol {
    var mockEncryptResult: Result<Data, Error> = .success(Data("encrypted".utf8))
    var mockDecryptResult: Result<Note, Error> = .success(Note(title: "Decrypted", content: "Decrypted"))
    
    var encryptNoteCalled = false
    var decryptNoteCalled = false
    
    func encryptNote(_ note: Note) throws -> Data {
        encryptNoteCalled = true
        
        switch mockEncryptResult {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
    
    func decryptNote(_ encryptedData: Data) throws -> Note {
        decryptNoteCalled = true
        
        switch mockDecryptResult {
        case .success(let note):
            return note
        case .failure(let error):
            throw error
        }
    }
}

class MockAPIClient: APIClientProtocol {
    var mockNetworkError: Error?
    var mockAPIError: APIError?
    
    func syncNotes(_ request: NoteSyncRequest) async throws -> NoteSyncResponse {
        if let error = mockNetworkError {
            throw error
        }
        
        if let error = mockAPIError {
            throw error
        }
        
        return NoteSyncResponse(notes: [], conflicts: [], serverTimestamp: Date())
    }
}

// MARK: - Error Types

enum NoteServiceError: Error, LocalizedError {
    case validationFailed(String)
    case noteNotFound
    case saveFailed
    case updateFailed
    case deleteFailed
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .noteNotFound:
            return "Note not found"
        case .saveFailed:
            return "Failed to save note"
        case .updateFailed:
            return "Failed to update note"
        case .deleteFailed:
            return "Failed to delete note"
        case .networkError:
            return "Network error"
        }
    }
}

enum CoreDataError: Error, LocalizedError {
    case saveFailed
    case fetchFailed
    case updateFailed
    case deleteFailed
    case concurrentModification
    case dataCorruption
    case batchSavePartialFailure
    case batchDeletePartialFailure
    
    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Core Data save failed"
        case .fetchFailed:
            return "Core Data fetch failed"
        case .updateFailed:
            return "Core Data update failed"
        case .deleteFailed:
            return "Core Data delete failed"
        case .concurrentModification:
            return "Concurrent modification detected"
        case .dataCorruption:
            return "Data corruption detected"
        case .batchSavePartialFailure:
            return "Batch save partially failed"
        case .batchDeletePartialFailure:
            return "Batch delete partially failed"
        }
    }
}

enum NetworkError: Error, LocalizedError {
    case noConnection
    case timeout
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No network connection"
        case .timeout:
            return "Network timeout"
        case .serverError:
            return "Server error"
        }
    }
}

// MARK: - Protocols

protocol CoreDataStackProtocol {
    func fetchAllNotes() async throws -> [Note]
    func fetchNote(id: UUID) async throws -> Note?
    func saveNote(_ note: Note) async throws -> Note
    func updateNote(_ note: Note) async throws -> Note
    func deleteNote(id: UUID) async throws
    func searchNotes(query: String) async throws -> [Note]
    func batchSaveNotes(_ notes: [Note]) async throws -> [Note]
    func batchDeleteNotes(ids: [UUID]) async throws
}

protocol EncryptionServiceProtocol {
    func encryptNote(_ note: Note) throws -> Data
    func decryptNote(_ encryptedData: Data) throws -> Note
}

protocol APIClientProtocol {
    func syncNotes(_ request: NoteSyncRequest) async throws -> NoteSyncResponse
}
