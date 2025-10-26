import Foundation
import Combine

// MARK: - Enhanced API Client

class EnhancedAPIClient {
    private let baseURL = "https://api.smartnotes.app"
    private let session: URLSession
    private let authManager: AuthManager
    private let retryManager: RetryManager
    
    init(authManager: AuthManager = AuthManager(), retryManager: RetryManager = RetryManager()) {
        self.authManager = authManager
        self.retryManager = retryManager
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.httpMaximumConnectionsPerHost = 6
        
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Authentication Endpoints
    
    func authenticate(email: String, password: String) async throws -> AuthResponse {
        let endpoint = APIEndpoint.authenticate(email: email, password: password)
        return try await performRequest(endpoint)
    }
    
    func refreshToken() async throws -> AuthResponse {
        let endpoint = APIEndpoint.refreshToken
        return try await performRequest(endpoint)
    }
    
    func logout() async throws {
        let endpoint = APIEndpoint.logout
        try await performRequest(endpoint)
    }
    
    // MARK: - Notes Endpoints
    
    func fetchNotes(since timestamp: Date? = nil, limit: Int = 50) async throws -> [Note] {
        let endpoint = APIEndpoint.fetchNotes(since: timestamp, limit: limit)
        let response: APIResponse<[Note]> = try await performRequest(endpoint)
        return response.data ?? []
    }
    
    func createNote(_ note: Note) async throws -> Note {
        let endpoint = APIEndpoint.createNote(note)
        let response: APIResponse<Note> = try await performRequest(endpoint)
        guard let createdNote = response.data else {
            throw APIError.invalidResponse
        }
        return createdNote
    }
    
    func updateNote(_ note: Note) async throws -> Note {
        let endpoint = APIEndpoint.updateNote(note)
        let response: APIResponse<Note> = try await performRequest(endpoint)
        guard let updatedNote = response.data else {
            throw APIError.invalidResponse
        }
        return updatedNote
    }
    
    func deleteNote(id: UUID) async throws {
        let endpoint = APIEndpoint.deleteNote(id: id)
        try await performRequest(endpoint)
    }
    
    func syncNotes(_ request: NoteSyncRequest) async throws -> NoteSyncResponse {
        let endpoint = APIEndpoint.syncNotes(request)
        let response: APIResponse<NoteSyncResponse> = try await performRequest(endpoint)
        guard let syncResponse = response.data else {
            throw APIError.invalidResponse
        }
        return syncResponse
    }
    
    // MARK: - Search Endpoints
    
    func searchNotes(query: String, filters: SearchFilters? = nil) async throws -> [Note] {
        let endpoint = APIEndpoint.searchNotes(query: query, filters: filters)
        let response: APIResponse<[Note]> = try await performRequest(endpoint)
        return response.data ?? []
    }
    
    // MARK: - File Upload Endpoints
    
    func uploadAttachment(_ data: Data, filename: String, noteId: UUID) async throws -> Attachment {
        let endpoint = APIEndpoint.uploadAttachment(data: data, filename: filename, noteId: noteId)
        let response: APIResponse<Attachment> = try await performRequest(endpoint)
        guard let attachment = response.data else {
            throw APIError.invalidResponse
        }
        return attachment
    }
    
    // MARK: - Generic Request Method
    
    private func performRequest<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        let request = try buildRequest(for: endpoint)
        
        return try await retryManager.performWithRetry {
            let (data, response) = try await self.session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            try self.handleHTTPResponse(httpResponse)
            
            let decodedResponse = try JSONDecoder().decode(T.self, from: data)
            return decodedResponse
        }
    }
    
    private func buildRequest(for endpoint: APIEndpoint) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("SmartNotes-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add authentication header
        if let token = authManager.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        // Add request body
        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
        // Add query parameters
        if let queryItems = endpoint.queryItems {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            request.url = components?.url
        }
        
        return request
    }
    
    private func handleHTTPResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return // Success
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 404:
            throw APIError.notFound
        case 409:
            throw APIError.conflict
        case 422:
            throw APIError.validationError
        case 429:
            throw APIError.rateLimited
        case 500...599:
            throw APIError.serverError
        default:
            throw APIError.unknownError(response.statusCode)
        }
    }
}

// MARK: - API Endpoint Definitions

enum APIEndpoint {
    case authenticate(email: String, password: String)
    case refreshToken
    case logout
    case fetchNotes(since: Date?, limit: Int)
    case createNote(Note)
    case updateNote(Note)
    case deleteNote(id: UUID)
    case syncNotes(NoteSyncRequest)
    case searchNotes(query: String, filters: SearchFilters?)
    case uploadAttachment(data: Data, filename: String, noteId: UUID)
    
    var path: String {
        switch self {
        case .authenticate:
            return "/auth/login"
        case .refreshToken:
            return "/auth/refresh"
        case .logout:
            return "/auth/logout"
        case .fetchNotes:
            return "/notes"
        case .createNote:
            return "/notes"
        case .updateNote(let note):
            return "/notes/\(note.id.uuidString)"
        case .deleteNote(let id):
            return "/notes/\(id.uuidString)"
        case .syncNotes:
            return "/notes/sync"
        case .searchNotes:
            return "/notes/search"
        case .uploadAttachment:
            return "/attachments"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .authenticate, .createNote, .syncNotes, .uploadAttachment:
            return .POST
        case .refreshToken, .fetchNotes, .searchNotes:
            return .GET
        case .updateNote:
            return .PUT
        case .deleteNote, .logout:
            return .DELETE
        }
    }
    
    var body: Codable? {
        switch self {
        case .authenticate(let email, let password):
            return AuthRequest(email: email, password: password)
        case .createNote(let note):
            return note
        case .updateNote(let note):
            return note
        case .syncNotes(let request):
            return request
        case .uploadAttachment(let data, let filename, let noteId):
            return AttachmentUploadRequest(data: data, filename: filename, noteId: noteId)
        default:
            return nil
        }
    }
    
    var queryItems: [URLQueryItem]? {
        switch self {
        case .fetchNotes(let since, let limit):
            var items = [URLQueryItem(name: "limit", value: String(limit))]
            if let since = since {
                items.append(URLQueryItem(name: "since", value: String(since.timeIntervalSince1970)))
            }
            return items
        case .searchNotes(let query, let filters):
            var items = [URLQueryItem(name: "q", value: query)]
            if let filters = filters {
                if let tags = filters.tags {
                    items.append(URLQueryItem(name: "tags", value: tags.joined(separator: ",")))
                }
                if let dateFrom = filters.dateFrom {
                    items.append(URLQueryItem(name: "date_from", value: String(dateFrom.timeIntervalSince1970)))
                }
                if let dateTo = filters.dateTo {
                    items.append(URLQueryItem(name: "date_to", value: String(dateTo.timeIntervalSince1970)))
                }
            }
            return items
        default:
            return nil
        }
    }
}

// MARK: - HTTP Method

enum HTTPMethod: String {
    case GET = "GET"
    case POST = "POST"
    case PUT = "PUT"
    case DELETE = "DELETE"
    case PATCH = "PATCH"
}

// MARK: - API Models

struct AuthRequest: Codable {
    let email: String
    let password: String
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User
}

struct User: Codable {
    let id: UUID
    let email: String
    let name: String
    let createdAt: Date
}

struct SearchFilters: Codable {
    let tags: [String]?
    let dateFrom: Date?
    let dateTo: Date?
    let isPinned: Bool?
    let color: NoteColor?
}

struct Attachment: Codable {
    let id: UUID
    let filename: String
    let url: String
    let size: Int
    let mimeType: String
    let noteId: UUID
    let createdAt: Date
}

struct AttachmentUploadRequest: Codable {
    let data: Data
    let filename: String
    let noteId: UUID
}

// MARK: - Authentication Manager

class AuthManager {
    private let keychain = KeychainService()
    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"
    
    var accessToken: String? {
        return try? keychain.getData(for: accessTokenKey).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    var refreshToken: String? {
        return try? keychain.getData(for: refreshTokenKey).flatMap { String(data: $0, encoding: .utf8) }
    }
    
    func saveTokens(accessToken: String, refreshToken: String) throws {
        try keychain.setData(accessToken.data(using: .utf8)!, for: accessTokenKey)
        try keychain.setData(refreshToken.data(using: .utf8)!, for: refreshTokenKey)
    }
    
    func clearTokens() throws {
        try keychain.deleteData(for: accessTokenKey)
        try keychain.deleteData(for: refreshTokenKey)
    }
    
    func isAuthenticated() -> Bool {
        return accessToken != nil
    }
}

// MARK: - Retry Manager

class RetryManager {
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    
    func performWithRetry<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry certain errors
                if shouldNotRetry(error) {
                    throw error
                }
                
                // Wait before retrying (exponential backoff)
                if attempt < maxRetries - 1 {
                    let delay = baseDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? APIError.unknownError(0)
    }
    
    private func shouldNotRetry(_ error: Error) -> Bool {
        if let apiError = error as? APIError {
            switch apiError {
            case .unauthorized, .forbidden, .notFound, .validationError:
                return true
            default:
                return false
            }
        }
        return false
    }
}

// MARK: - Enhanced API Errors

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case validationError
    case rateLimited
    case serverError
    case networkError(String)
    case unknownError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .conflict:
            return "Resource conflict"
        case .validationError:
            return "Validation error"
        case .rateLimited:
            return "Rate limit exceeded"
        case .serverError:
            return "Server error"
        case .networkError(let message):
            return "Network error: \(message)"
        case .unknownError(let code):
            return "Unknown error (code: \(code))"
        }
    }
}

// MARK: - API Documentation Generator

class APIDocumentationGenerator {
    static func generateMarkdown() -> String {
        return """
        # Smart Notes API Documentation
        
        ## Base URL
        `https://api.smartnotes.app`
        
        ## Authentication
        All API requests require authentication via Bearer token in the Authorization header:
        ```
        Authorization: Bearer <access_token>
        ```
        
        ## Endpoints
        
        ### Authentication
        
        #### POST /auth/login
        Authenticate user and receive access token.
        
        **Request Body:**
        ```json
        {
            "email": "user@example.com",
            "password": "password123"
        }
        ```
        
        **Response:**
        ```json
        {
            "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
            "refreshToken": "refresh_token_here",
            "expiresIn": 3600,
            "user": {
                "id": "uuid",
                "email": "user@example.com",
                "name": "John Doe",
                "createdAt": "2024-01-01T00:00:00Z"
            }
        }
        ```
        
        ### Notes
        
        #### GET /notes
        Fetch user's notes with optional filtering.
        
        **Query Parameters:**
        - `since` (optional): Unix timestamp to fetch notes since
        - `limit` (optional): Maximum number of notes to return (default: 50)
        
        **Response:**
        ```json
        {
            "success": true,
            "data": [
                {
                    "id": "uuid",
                    "title": "Note Title",
                    "content": "Note content...",
                    "createdAt": "2024-01-01T00:00:00Z",
                    "updatedAt": "2024-01-01T00:00:00Z",
                    "tags": ["tag1", "tag2"],
                    "isEncrypted": false,
                    "isPinned": false,
                    "color": "default"
                }
            ],
            "error": null
        }
        ```
        
        #### POST /notes
        Create a new note.
        
        **Request Body:**
        ```json
        {
            "title": "New Note",
            "content": "Note content...",
            "tags": ["tag1", "tag2"],
            "color": "blue"
        }
        ```
        
        #### PUT /notes/{id}
        Update an existing note.
        
        #### DELETE /notes/{id}
        Delete a note.
        
        ### Sync
        
        #### POST /notes/sync
        Synchronize notes between devices.
        
        **Request Body:**
        ```json
        {
            "notes": [...],
            "lastSyncTimestamp": "2024-01-01T00:00:00Z",
            "deviceId": "device_uuid"
        }
        ```
        
        **Response:**
        ```json
        {
            "success": true,
            "data": {
                "notes": [...],
                "conflicts": [...],
                "serverTimestamp": "2024-01-01T00:00:00Z"
            }
        }
        ```
        
        ### Search
        
        #### GET /notes/search
        Search notes with query and filters.
        
        **Query Parameters:**
        - `q`: Search query
        - `tags` (optional): Comma-separated tags
        - `date_from` (optional): Start date filter
        - `date_to` (optional): End date filter
        
        ## Error Handling
        
        All API responses follow this format:
        ```json
        {
            "success": false,
            "data": null,
            "error": {
                "code": 400,
                "message": "Error description",
                "details": "Additional error details"
            }
        }
        ```
        
        ## Rate Limiting
        
        API requests are rate limited to 1000 requests per hour per user.
        
        ## Security
        
        - All communication uses HTTPS
        - Access tokens expire after 1 hour
        - Refresh tokens expire after 30 days
        - Sensitive data is encrypted using AES-256
        """
    }
}
