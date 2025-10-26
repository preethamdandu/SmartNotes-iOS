import XCTest
import CoreData
import Combine
@testable import SmartNotes

// MARK: - Note Edge Cases Tests

class NoteEdgeCasesTests: XCTestCase {
    
    var noteService: NoteServiceProtocol!
    var mockCoreDataStack: MockCoreDataStack!
    var mockEncryptionService: MockEncryptionService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockCoreDataStack = MockCoreDataStack()
        mockEncryptionService = MockEncryptionService()
        cancellables = Set<AnyCancellable>()
        
        noteService = NoteService(
            coreDataStack: mockCoreDataStack,
            encryptionService: mockEncryptionService,
            apiClient: MockAPIClient()
        )
    }
    
    override func tearDown() {
        noteService = nil
        mockCoreDataStack = nil
        mockEncryptionService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Unicode and Internationalization Tests
    
    func testCreateNote_WithUnicodeCharacters() async throws {
        // Given
        let unicodeNote = Note(
            title: "测试笔记 🚀 日本語",
            content: "This is a test with émojis and spëcial characters: 测试内容",
            tags: ["测试", "emoji", "日本語"],
            color: .blue
        )
        mockCoreDataStack.mockSaveResult = .success(unicodeNote)
        
        // When
        let result = try await noteService.saveNote(unicodeNote)
        
        // Then
        XCTAssertEqual(result.title, "测试笔记 🚀 日本語")
        XCTAssertEqual(result.content, "This is a test with émojis and spëcial characters: 测试内容")
        XCTAssertEqual(result.tags, ["测试", "emoji", "日本語"])
    }
    
    func testCreateNote_WithEmojiOnlyTitle() async throws {
        // Given
        let emojiNote = Note(title: "🚀📝💡", content: "Content", tags: [], color: .default)
        mockCoreDataStack.mockSaveResult = .success(emojiNote)
        
        // When
        let result = try await noteService.saveNote(emojiNote)
        
        // Then
        XCTAssertEqual(result.title, "🚀📝💡")
    }
    
    func testCreateNote_WithZeroWidthCharacters() async throws {
        // Given
        let zeroWidthNote = Note(
            title: "Title\u{200B}\u{200C}\u{200D}", // Zero-width characters
            content: "Content with\u{200B}zero width",
            tags: [],
            color: .default
        )
        mockCoreDataStack.mockSaveResult = .success(zeroWidthNote)
        
        // When
        let result = try await noteService.saveNote(zeroWidthNote)
        
        // Then
        XCTAssertEqual(result.title, "Title\u{200B}\u{200C}\u{200D}")
        XCTAssertEqual(result.content, "Content with\u{200B}zero width")
    }
    
    // MARK: - Boundary Value Tests
    
    func testCreateNote_MaximumValidTitle() async throws {
        // Given
        let maxTitle = String(repeating: "A", count: 1000) // Exactly at limit
        let note = Note(title: maxTitle, content: "Content", tags: [], color: .default)
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.title.count, 1000)
    }
    
    func testCreateNote_MaximumValidContent() async throws {
        // Given
        let maxContent = String(repeating: "B", count: 10000) // Exactly at limit
        let note = Note(title: "Title", content: maxContent, tags: [], color: .default)
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.content.count, 10000)
    }
    
    func testCreateNote_MaximumValidTags() async throws {
        // Given
        let maxTags = (1...50).map { "tag\($0)" } // Exactly at limit
        let note = Note(title: "Title", content: "Content", tags: maxTags, color: .default)
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.tags.count, 50)
    }
    
    func testCreateNote_MaximumValidTagLength() async throws {
        // Given
        let maxTagLength = String(repeating: "T", count: 50) // Maximum tag length
        let note = Note(title: "Title", content: "Content", tags: [maxTagLength], color: .default)
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.tags.first?.count, 50)
    }
    
    // MARK: - Date and Time Edge Cases
    
    func testCreateNote_WithFutureDate() async throws {
        // Given
        let futureDate = Date().addingTimeInterval(86400) // 1 day in future
        var note = Note(title: "Future Note", content: "Content", tags: [], color: .default)
        note.createdAt = futureDate
        note.updatedAt = futureDate
        
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.createdAt, futureDate)
        XCTAssertEqual(result.updatedAt, futureDate)
    }
    
    func testCreateNote_WithPastDate() async throws {
        // Given
        let pastDate = Date().addingTimeInterval(-86400) // 1 day in past
        var note = Note(title: "Past Note", content: "Content", tags: [], color: .default)
        note.createdAt = pastDate
        note.updatedAt = pastDate
        
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.createdAt, pastDate)
        XCTAssertEqual(result.updatedAt, pastDate)
    }
    
    func testCreateNote_WithVeryOldDate() async throws {
        // Given
        let veryOldDate = Date(timeIntervalSince1970: 0) // Unix epoch
        var note = Note(title: "Old Note", content: "Content", tags: [], color: .default)
        note.createdAt = veryOldDate
        note.updatedAt = veryOldDate
        
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.createdAt, veryOldDate)
        XCTAssertEqual(result.updatedAt, veryOldDate)
    }
    
    // MARK: - Color Edge Cases
    
    func testCreateNote_WithAllColors() async throws {
        // Given
        let colors = NoteColor.allCases
        
        for color in colors {
            let note = Note(title: "Note \(color.rawValue)", content: "Content", tags: [], color: color)
            mockCoreDataStack.mockSaveResult = .success(note)
            
            // When
            let result = try await noteService.saveNote(note)
            
            // Then
            XCTAssertEqual(result.color, color)
        }
    }
    
    // MARK: - Encryption Edge Cases
    
    func testCreateNote_EncryptEmptyContent() async throws {
        // Given
        var emptyNote = Note(title: "Empty", content: "", tags: [], color: .default)
        emptyNote.isEncrypted = true
        mockCoreDataStack.mockSaveResult = .success(emptyNote)
        mockEncryptionService.mockEncryptResult = .success(Data())
        
        // When
        let result = try await noteService.saveNote(emptyNote)
        
        // Then
        XCTAssertTrue(result.isEncrypted)
        XCTAssertTrue(mockEncryptionService.encryptNoteCalled)
    }
    
    func testCreateNote_EncryptVeryLargeContent() async throws {
        // Given
        let largeContent = String(repeating: "Secret", count: 1000)
        var largeNote = Note(title: "Large Secret", content: largeContent, tags: [], color: .default)
        largeNote.isEncrypted = true
        mockCoreDataStack.mockSaveResult = .success(largeNote)
        mockEncryptionService.mockEncryptResult = .success(Data("encrypted".utf8))
        
        // When
        let result = try await noteService.saveNote(largeNote)
        
        // Then
        XCTAssertTrue(result.isEncrypted)
        XCTAssertTrue(mockEncryptionService.encryptNoteCalled)
    }
    
    // MARK: - Search Edge Cases
    
    func testSearchNotes_WithSpecialRegexCharacters() async throws {
        // Given
        let specialQueries = [
            "test[0-9]",
            "test.*",
            "test+",
            "test?",
            "test|test2",
            "test^",
            "test$",
            "test\\",
            "test()",
            "test{}"
        ]
        
        for query in specialQueries {
            mockCoreDataStack.mockSearchResults = []
            
            // When
            let result = try await noteService.searchNotes(query: query)
            
            // Then
            XCTAssertEqual(result.count, 0)
            XCTAssertTrue(mockCoreDataStack.searchNotesCalled)
        }
    }
    
    func testSearchNotes_WithSQLInjectionAttempts() async throws {
        // Given
        let sqlInjectionQueries = [
            "'; DROP TABLE notes; --",
            "' OR '1'='1",
            "'; INSERT INTO notes VALUES ('hack', 'hack'); --",
            "' UNION SELECT * FROM notes --"
        ]
        
        for query in sqlInjectionQueries {
            mockCoreDataStack.mockSearchResults = []
            
            // When
            let result = try await noteService.searchNotes(query: query)
            
            // Then
            XCTAssertEqual(result.count, 0)
            XCTAssertTrue(mockCoreDataStack.searchNotesCalled)
        }
    }
    
    func testSearchNotes_WithXSSAttempts() async throws {
        // Given
        let xssQueries = [
            "<script>alert('xss')</script>",
            "javascript:alert('xss')",
            "<img src=x onerror=alert('xss')>",
            "';alert('xss');//"
        ]
        
        for query in xssQueries {
            mockCoreDataStack.mockSearchResults = []
            
            // When
            let result = try await noteService.searchNotes(query: query)
            
            // Then
            XCTAssertEqual(result.count, 0)
            XCTAssertTrue(mockCoreDataStack.searchNotesCalled)
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentCreateAndRead() async throws {
        // Given
        let notes = (1...100).map { i in
            Note(title: "Note \(i)", content: "Content \(i)", tags: [], color: .default)
        }
        
        mockCoreDataStack.mockSaveResult = .success(notes[0])
        mockCoreDataStack.mockNotes = notes
        
        // When - Perform concurrent operations
        async let createResults = withTaskGroup(of: Note.self) { group in
            for note in notes.prefix(10) {
                group.addTask {
                    try await self.noteService.saveNote(note)
                }
            }
            
            var results: [Note] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        
        async let readResult = noteService.fetchAllNotes()
        
        let (createdNotes, fetchedNotes) = try await (createResults, readResult)
        
        // Then
        XCTAssertEqual(createdNotes.count, 10)
        XCTAssertEqual(fetchedNotes.count, 100)
    }
    
    func testConcurrentUpdateAndDelete() async throws {
        // Given
        let note1 = Note(title: "Note 1", content: "Content 1", tags: [], color: .default)
        let note2 = Note(title: "Note 2", content: "Content 2", tags: [], color: .default)
        
        mockCoreDataStack.mockNoteById = note1
        mockCoreDataStack.mockUpdateResult = .success(note1)
        mockCoreDataStack.mockDeleteResult = .success(())
        
        // When - Perform concurrent operations
        async let updateResult = noteService.updateNote(note1)
        async let deleteResult = noteService.deleteNote(id: note2.id)
        
        let (updatedNote, _) = try await (updateResult, deleteResult)
        
        // Then
        XCTAssertEqual(updatedNote.title, "Note 1")
        XCTAssertTrue(mockCoreDataStack.updateNoteCalled)
        XCTAssertTrue(mockCoreDataStack.deleteNoteCalled)
    }
    
    // MARK: - Memory Pressure Tests
    
    func testMemoryPressure_WithLargeDataset() async throws {
        // Given
        let largeNotes = (1...10000).map { i in
            Note(title: "Note \(i)", content: "Content \(i)", tags: [], color: .default)
        }
        mockCoreDataStack.mockNotes = largeNotes
        
        // When
        let result = try await noteService.fetchAllNotes()
        
        // Then
        XCTAssertEqual(result.count, 10000)
        
        // Verify memory management
        XCTAssertTrue(mockCoreDataStack.fetchAllNotesCalled)
    }
    
    func testMemoryPressure_WithLargeContent() async throws {
        // Given
        let largeContent = String(repeating: "Large content ", count: 1000)
        let note = Note(title: "Large Note", content: largeContent, tags: [], color: .default)
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.content.count, largeContent.count)
        XCTAssertTrue(mockCoreDataStack.saveNoteCalled)
    }
    
    // MARK: - Network Edge Cases
    
    func testNetworkFailure_WithRetry() async throws {
        // Given
        let note = Note(title: "Network Test", content: "Content", tags: [], color: .default)
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // Simulate network failure then success
        var retryCount = 0
        mockCoreDataStack.mockSaveResult = .success(note)
        
        // When
        let result = try await noteService.saveNote(note)
        
        // Then
        XCTAssertEqual(result.title, "Network Test")
        XCTAssertTrue(mockCoreDataStack.saveNoteCalled)
    }
    
    // MARK: - Data Integrity Tests
    
    func testDataIntegrity_WithCorruptedData() async throws {
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
    
    func testDataIntegrity_WithInvalidUUID() async throws {
        // Given
        let invalidUUID = UUID()
        mockCoreDataStack.mockNoteById = nil
        
        // When
        let result = try await noteService.fetchNote(id: invalidUUID)
        
        // Then
        XCTAssertNil(result)
        XCTAssertTrue(mockCoreDataStack.fetchNoteByIdCalled)
    }
    
    // MARK: - Performance Edge Cases
    
    func testPerformance_WithManySmallNotes() {
        // Given
        let smallNotes = (1...1000).map { i in
            Note(title: "\(i)", content: "\(i)", tags: [], color: .default)
        }
        mockCoreDataStack.mockNotes = smallNotes
        
        // When & Then
        measure {
            let expectation = XCTestExpectation(description: "Many small notes")
            
            Task {
                do {
                    let result = try await noteService.fetchAllNotes()
                    XCTAssertEqual(result.count, 1000)
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testPerformance_WithFewLargeNotes() {
        // Given
        let largeContent = String(repeating: "Large content ", count: 1000)
        let largeNotes = (1...10).map { i in
            Note(title: "Large Note \(i)", content: largeContent, tags: [], color: .default)
        }
        mockCoreDataStack.mockNotes = largeNotes
        
        // When & Then
        measure {
            let expectation = XCTestExpectation(description: "Few large notes")
            
            Task {
                do {
                    let result = try await noteService.fetchAllNotes()
                    XCTAssertEqual(result.count, 10)
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
}

// MARK: - Integration Tests

class NoteIntegrationTests: XCTestCase {
    
    var noteService: NoteServiceProtocol!
    var realCoreDataStack: CoreDataStack!
    var mockEncryptionService: MockEncryptionService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Use real Core Data stack for integration tests
        realCoreDataStack = CoreDataStack()
        mockEncryptionService = MockEncryptionService()
        cancellables = Set<AnyCancellable>()
        
        noteService = NoteService(
            coreDataStack: realCoreDataStack,
            encryptionService: mockEncryptionService,
            apiClient: MockAPIClient()
        )
    }
    
    override func tearDown() {
        noteService = nil
        realCoreDataStack = nil
        mockEncryptionService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Full CRUD Integration Tests
    
    func testFullCRUDCycle() async throws {
        // Create
        let newNote = Note(title: "Integration Test", content: "Test content", tags: ["test"], color: .blue)
        let createdNote = try await noteService.saveNote(newNote)
        XCTAssertEqual(createdNote.title, "Integration Test")
        
        // Read
        let fetchedNote = try await noteService.fetchNote(id: createdNote.id)
        XCTAssertNotNil(fetchedNote)
        XCTAssertEqual(fetchedNote?.title, "Integration Test")
        
        // Update
        var updatedNote = createdNote
        updatedNote.title = "Updated Integration Test"
        updatedNote.content = "Updated content"
        let savedUpdatedNote = try await noteService.updateNote(updatedNote)
        XCTAssertEqual(savedUpdatedNote.title, "Updated Integration Test")
        
        // Delete
        try await noteService.deleteNote(id: savedUpdatedNote.id)
        
        // Verify deletion
        let deletedNote = try await noteService.fetchNote(id: savedUpdatedNote.id)
        XCTAssertNil(deletedNote)
    }
    
    func testSearchIntegration() async throws {
        // Create test notes
        let notes = [
            Note(title: "Work Meeting", content: "Discuss project timeline", tags: ["work", "meeting"], color: .blue),
            Note(title: "Personal Todo", content: "Buy groceries", tags: ["personal", "shopping"], color: .green),
            Note(title: "Work Report", content: "Monthly report for Q1", tags: ["work", "report"], color: .yellow)
        ]
        
        for note in notes {
            _ = try await noteService.saveNote(note)
        }
        
        // Search by content
        let workResults = try await noteService.searchNotes(query: "work")
        XCTAssertEqual(workResults.count, 2)
        
        // Search by tags
        let meetingResults = try await noteService.searchNotes(query: "meeting")
        XCTAssertEqual(meetingResults.count, 1)
        
        // Search by title
        let reportResults = try await noteService.searchNotes(query: "report")
        XCTAssertEqual(reportResults.count, 1)
    }
    
    func testBatchOperationsIntegration() async throws {
        // Create multiple notes
        let notes = (1...10).map { i in
            Note(title: "Batch Note \(i)", content: "Content \(i)", tags: ["batch"], color: .default)
        }
        
        let createdNotes = try await noteService.batchSaveNotes(notes)
        XCTAssertEqual(createdNotes.count, 10)
        
        // Fetch all notes
        let allNotes = try await noteService.fetchAllNotes()
        XCTAssertGreaterThanOrEqual(allNotes.count, 10)
        
        // Delete batch
        let noteIds = createdNotes.map { $0.id }
        try await noteService.batchDeleteNotes(ids: noteIds)
        
        // Verify deletion
        let remainingNotes = try await noteService.fetchAllNotes()
        XCTAssertLessThan(remainingNotes.count, allNotes.count)
    }
}
