# Smart Notes API Documentation

## Overview

The Smart Notes API provides a comprehensive RESTful interface for managing notes across devices with real-time synchronization, advanced search capabilities, and enterprise-grade security.

## Base URL

```
https://api.smartnotes.app
```

## Authentication

All API requests require authentication via Bearer token in the Authorization header:

```
Authorization: Bearer <access_token>
```

### Token Management

- **Access Token**: Valid for 1 hour
- **Refresh Token**: Valid for 30 days
- **Auto-refresh**: Automatic token renewal
- **Revocation**: Immediate token invalidation on logout

## Rate Limiting

- **Limit**: 1000 requests per hour per user
- **Headers**: Rate limit information in response headers
- **Exceeded**: HTTP 429 with retry-after header

## Error Handling

All API responses follow this consistent format:

```json
{
  "success": boolean,
  "data": object | null,
  "error": {
    "code": number,
    "message": string,
    "details": string | null
  } | null
}
```

### HTTP Status Codes

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 409 | Conflict |
| 422 | Validation Error |
| 429 | Rate Limited |
| 500 | Internal Server Error |

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
  "success": true,
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "refresh_token_here",
    "expiresIn": 3600,
    "user": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "email": "user@example.com",
      "name": "John Doe",
      "createdAt": "2024-01-01T00:00:00Z"
    }
  },
  "error": null
}
```

#### POST /auth/refresh

Refresh expired access token.

**Request Body:**
```json
{
  "refreshToken": "refresh_token_here"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "accessToken": "new_access_token",
    "expiresIn": 3600
  },
  "error": null
}
```

#### DELETE /auth/logout

Invalidate current session.

**Response:**
```json
{
  "success": true,
  "data": null,
  "error": null
}
```

### Notes Management

#### GET /notes

Fetch user's notes with optional filtering and pagination.

**Query Parameters:**
- `since` (optional): Unix timestamp to fetch notes since
- `limit` (optional): Maximum number of notes to return (default: 50, max: 100)
- `tags` (optional): Comma-separated list of tags to filter by
- `pinned` (optional): Filter by pinned status (true/false)

**Example Request:**
```
GET /notes?since=1640995200&limit=20&tags=work,important&pinned=true
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "Meeting Notes",
      "content": "Discussion about project timeline...",
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T12:00:00Z",
      "tags": ["work", "meeting"],
      "isEncrypted": false,
      "isPinned": true,
      "color": "blue",
      "syncStatus": "synced"
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
  "content": "Note content here...",
  "tags": ["tag1", "tag2"],
  "color": "blue",
  "isEncrypted": false,
  "isPinned": false
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "New Note",
    "content": "Note content here...",
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T00:00:00Z",
    "tags": ["tag1", "tag2"],
    "isEncrypted": false,
    "isPinned": false,
    "color": "blue",
    "syncStatus": "pending"
  },
  "error": null
}
```

#### PUT /notes/{id}

Update an existing note.

**Path Parameters:**
- `id`: Note UUID

**Request Body:**
```json
{
  "title": "Updated Note Title",
  "content": "Updated content...",
  "tags": ["updated", "tags"],
  "color": "green",
  "isPinned": true
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Updated Note Title",
    "content": "Updated content...",
    "createdAt": "2024-01-01T00:00:00Z",
    "updatedAt": "2024-01-01T13:00:00Z",
    "tags": ["updated", "tags"],
    "isEncrypted": false,
    "isPinned": true,
    "color": "green",
    "syncStatus": "pending"
  },
  "error": null
}
```

#### DELETE /notes/{id}

Delete a note permanently.

**Path Parameters:**
- `id`: Note UUID

**Response:**
```json
{
  "success": true,
  "data": null,
  "error": null
}
```

### Synchronization

#### POST /notes/sync

Synchronize notes between devices with conflict resolution.

**Request Body:**
```json
{
  "notes": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "Local Note",
      "content": "Content modified locally",
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T14:00:00Z",
      "tags": ["local"],
      "isEncrypted": false,
      "isPinned": false,
      "color": "default",
      "syncStatus": "pending"
    }
  ],
  "lastSyncTimestamp": "2024-01-01T12:00:00Z",
  "deviceId": "device-uuid-here"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "notes": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440001",
        "title": "Server Note",
        "content": "Content from server",
        "createdAt": "2024-01-01T01:00:00Z",
        "updatedAt": "2024-01-01T15:00:00Z",
        "tags": ["server"],
        "isEncrypted": false,
        "isPinned": false,
        "color": "yellow",
        "syncStatus": "synced"
      }
    ],
    "conflicts": [
      {
        "noteId": "550e8400-e29b-41d4-a716-446655440000",
        "localVersion": {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "title": "Local Note",
          "content": "Content modified locally",
          "updatedAt": "2024-01-01T14:00:00Z"
        },
        "serverVersion": {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "title": "Local Note",
          "content": "Content modified on server",
          "updatedAt": "2024-01-01T13:00:00Z"
        },
        "conflictType": "content_modified"
      }
    ],
    "serverTimestamp": "2024-01-01T16:00:00Z"
  },
  "error": null
}
```

#### POST /notes/sync/resolve

Resolve sync conflicts.

**Request Body:**
```json
{
  "conflictId": "550e8400-e29b-41d4-a716-446655440000",
  "resolution": "use_local",
  "resolvedNote": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Resolved Note",
    "content": "Merged content from both versions",
    "updatedAt": "2024-01-01T16:00:00Z"
  }
}
```

**Resolution Options:**
- `use_local`: Use local version
- `use_server`: Use server version
- `merge`: Merge both versions

### Search

#### GET /notes/search

Search notes with advanced filtering.

**Query Parameters:**
- `q` (required): Search query string
- `tags` (optional): Comma-separated tags to filter by
- `date_from` (optional): Start date filter (Unix timestamp)
- `date_to` (optional): End date filter (Unix timestamp)
- `color` (optional): Filter by note color
- `pinned` (optional): Filter by pinned status
- `limit` (optional): Maximum results (default: 50)

**Example Request:**
```
GET /notes/search?q=meeting&tags=work&date_from=1640995200&limit=20
```

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "title": "Team Meeting Notes",
      "content": "Discussion about project timeline and deliverables...",
      "createdAt": "2024-01-01T00:00:00Z",
      "updatedAt": "2024-01-01T12:00:00Z",
      "tags": ["work", "meeting"],
      "isEncrypted": false,
      "isPinned": false,
      "color": "blue",
      "syncStatus": "synced",
      "relevanceScore": 0.95
    }
  ],
  "error": null
}
```

### File Attachments

#### POST /attachments

Upload file attachment to a note.

**Request Body:** (multipart/form-data)
- `file`: File data
- `filename`: Original filename
- `noteId`: Target note UUID
- `mimeType`: File MIME type

**Response:**
```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "filename": "document.pdf",
    "url": "https://api.smartnotes.app/attachments/550e8400-e29b-41d4-a716-446655440000",
    "size": 1024000,
    "mimeType": "application/pdf",
    "noteId": "550e8400-e29b-41d4-a716-446655440001",
    "createdAt": "2024-01-01T00:00:00Z"
  },
  "error": null
}
```

#### GET /attachments/{id}

Download file attachment.

**Path Parameters:**
- `id`: Attachment UUID

**Response:** Binary file data with appropriate Content-Type header

#### DELETE /attachments/{id}

Delete file attachment.

**Path Parameters:**
- `id`: Attachment UUID

**Response:**
```json
{
  "success": true,
  "data": null,
  "error": null
}
```

## Data Models

### Note

```json
{
  "id": "string (UUID)",
  "title": "string",
  "content": "string",
  "createdAt": "string (ISO 8601)",
  "updatedAt": "string (ISO 8601)",
  "tags": ["string"],
  "isEncrypted": "boolean",
  "isPinned": "boolean",
  "color": "string (enum)",
  "syncStatus": "string (enum)"
}
```

**Color Options:**
- `default`
- `yellow`
- `green`
- `blue`
- `purple`
- `pink`
- `orange`

**Sync Status Options:**
- `synced`
- `pending`
- `conflict`
- `error`

### User

```json
{
  "id": "string (UUID)",
  "email": "string",
  "name": "string",
  "createdAt": "string (ISO 8601)"
}
```

### Attachment

```json
{
  "id": "string (UUID)",
  "filename": "string",
  "url": "string",
  "size": "number",
  "mimeType": "string",
  "noteId": "string (UUID)",
  "createdAt": "string (ISO 8601)"
}
```

## Error Codes

| Code | Description |
|------|-------------|
| 1000 | Invalid request format |
| 1001 | Missing required field |
| 1002 | Invalid field value |
| 2000 | Authentication required |
| 2001 | Invalid credentials |
| 2002 | Token expired |
| 2003 | Token invalid |
| 3000 | Note not found |
| 3001 | Attachment not found |
| 3002 | User not found |
| 4000 | Sync conflict detected |
| 4001 | Version mismatch |
| 5000 | Internal server error |
| 5001 | Database error |
| 5002 | External service error |

## SDK Examples

### Swift/iOS

```swift
import Foundation

class SmartNotesAPI {
    private let baseURL = "https://api.smartnotes.app"
    private let session = URLSession.shared
    
    func fetchNotes() async throws -> [Note] {
        let url = URL(string: "\(baseURL)/notes")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        let apiResponse = try JSONDecoder().decode(APIResponse<[Note]>.self, from: data)
        
        return apiResponse.data ?? []
    }
    
    func createNote(_ note: Note) async throws -> Note {
        let url = URL(string: "\(baseURL)/notes")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(note)
        
        let (data, response) = try await session.data(for: request)
        let apiResponse = try JSONDecoder().decode(APIResponse<Note>.self, from: data)
        
        guard let createdNote = apiResponse.data else {
            throw APIError.invalidResponse
        }
        
        return createdNote
    }
}
```

### JavaScript/Web

```javascript
class SmartNotesAPI {
    constructor(baseURL = 'https://api.smartnotes.app') {
        this.baseURL = baseURL;
        this.accessToken = localStorage.getItem('accessToken');
    }
    
    async fetchNotes() {
        const response = await fetch(`${this.baseURL}/notes`, {
            headers: {
                'Authorization': `Bearer ${this.accessToken}`,
                'Content-Type': 'application/json'
            }
        });
        
        const data = await response.json();
        return data.data || [];
    }
    
    async createNote(note) {
        const response = await fetch(`${this.baseURL}/notes`, {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${this.accessToken}`,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(note)
        });
        
        const data = await response.json();
        return data.data;
    }
}
```

## Webhooks

### Note Events

Configure webhooks to receive real-time notifications for note changes.

**Webhook URL:** `POST /webhooks/notes`

**Events:**
- `note.created`
- `note.updated`
- `note.deleted`
- `note.shared`

**Payload Example:**
```json
{
  "event": "note.updated",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "noteId": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "550e8400-e29b-41d4-a716-446655440001",
    "changes": ["title", "content"]
  }
}
```

## Security Considerations

### Data Encryption
- All sensitive data encrypted with AES-256
- End-to-end encryption for note content
- Secure key management with Keychain Services

### Authentication
- JWT tokens with short expiration
- Refresh token rotation
- Biometric authentication support

### Privacy
- No data collection without consent
- GDPR compliant data handling
- Right to data deletion

## Support

For API support and questions:
- **Email**: api-support@smartnotes.app
- **Documentation**: https://docs.smartnotes.app
- **Status Page**: https://status.smartnotes.app

---

**API Version**: 1.0  
**Last Updated**: January 2024
