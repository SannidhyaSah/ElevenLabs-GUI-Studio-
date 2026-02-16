import Foundation

// MARK: - ElevenLabs API Client

/// Async/await HTTP client for the ElevenLabs REST API.
/// Uses URLSession with no third-party dependencies.
actor ElevenLabsAPI {
    
    private let baseURL = "https://api.elevenlabs.io"
    private let session: URLSession
    private var apiKey: String?
    
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Configuration
    
    /// Set the API key for authentication.
    func setAPIKey(_ key: String?) {
        self.apiKey = key
    }
    
    /// Test if the current API key is valid by making a lightweight request.
    func validateAPIKey() async throws -> Bool {
        let _ = try await fetchVoices(pageSize: 1)
        return true
    }
    
    // MARK: - Voices
    
    /// Fetch user's voices with optional search and filtering.
    /// Endpoint: GET /v1/voices
    func fetchVoices(
        pageSize: Int = 100,
        search: String? = nil,
        voiceType: String? = nil,
        category: String? = nil,
        nextPageToken: String? = nil
    ) async throws -> VoicesResponse {
        var components = URLComponents(string: "\(baseURL)/v1/voices")!
        var queryItems = [URLQueryItem(name: "page_size", value: "\(min(pageSize, 100))")]
        
        if let search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let voiceType {
            queryItems.append(URLQueryItem(name: "voice_type", value: voiceType))
        }
        if let category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let nextPageToken {
            queryItems.append(URLQueryItem(name: "next_page_token", value: nextPageToken))
        }
        
        components.queryItems = queryItems
        
        let data = try await performRequest(url: components.url!, method: "GET")
        return try decoder.decode(VoicesResponse.self, from: data)
    }
    
    // MARK: - Models
    
    /// Fetch all available AI models.
    /// Endpoint: GET /v1/models
    func fetchModels() async throws -> [AIModel] {
        let url = URL(string: "\(baseURL)/v1/models")!
        let data = try await performRequest(url: url, method: "GET")
        
        // Models endpoint returns a JSON array directly
        let allModels = try decoder.decode([AIModel].self, from: data)
        
        // Filter to only models that support TTS
        return allModels.filter { $0.canDoTextToSpeech ?? false }
    }
    
    // MARK: - Text to Speech
    
    /// Generate speech from text.
    /// Endpoint: POST /v1/text-to-speech/{voice_id}
    func generateSpeech(
        text: String,
        voiceId: String,
        modelId: String = "eleven_multilingual_v2",
        voiceSettings: VoiceSettings? = nil,
        outputFormat: OutputFormat = .mp3_44100_128,
        languageCode: String? = nil,
        seed: Int? = nil,
        previousText: String? = nil,
        nextText: String? = nil,
        textNormalization: TextNormalization = .auto
    ) async throws -> Data {
        var urlComponents = URLComponents(string: "\(baseURL)/v1/text-to-speech/\(voiceId)")!
        urlComponents.queryItems = [
            URLQueryItem(name: "output_format", value: outputFormat.rawValue)
        ]
        
        // Build request body
        var body: [String: Any] = [
            "text": text,
            "model_id": modelId,
            "apply_text_normalization": textNormalization.rawValue
        ]
        
        if let languageCode {
            body["language_code"] = languageCode
        }
        
        if let seed {
            body["seed"] = seed
        }
        
        if let previousText {
            body["previous_text"] = previousText
        }
        
        if let nextText {
            body["next_text"] = nextText
        }
        
        if let settings = voiceSettings?.clamped {
            body["voice_settings"] = [
                "stability": settings.stability,
                "similarity_boost": settings.similarityBoost,
                "style": settings.style,
                "speed": settings.speed,
                "use_speaker_boost": settings.useSpeakerBoost
            ]
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequest(
            url: urlComponents.url!,
            method: "POST",
            body: jsonData,
            contentType: "application/json"
        )
    }
    
    // MARK: - Voice Cloning
    
    /// Create an instant voice clone.
    /// Endpoint: POST /v1/voices/add (multipart form data)
    func cloneVoice(
        name: String,
        description: String? = nil,
        labels: [String: String]? = nil,
        audioFiles: [(filename: String, data: Data)],
        removeBackgroundNoise: Bool = false
    ) async throws -> VoiceCloneResponse {
        let url = URL(string: "\(baseURL)/v1/voices/add")!
        let boundary = UUID().uuidString
        
        var body = Data()
        
        // Name field
        body.appendMultipartField(name: "name", value: name, boundary: boundary)
        
        // Description field
        if let description, !description.isEmpty {
            body.appendMultipartField(name: "description", value: description, boundary: boundary)
        }
        
        // Labels field
        if let labels, !labels.isEmpty {
            let labelsJSON = try JSONSerialization.data(withJSONObject: labels)
            if let labelsString = String(data: labelsJSON, encoding: .utf8) {
                body.appendMultipartField(name: "labels", value: labelsString, boundary: boundary)
            }
        }
        
        // Remove background noise
        body.appendMultipartField(
            name: "remove_background_noise",
            value: removeBackgroundNoise ? "true" : "false",
            boundary: boundary
        )
        
        // Audio files
        for file in audioFiles {
            body.appendMultipartFile(
                name: "files",
                filename: file.filename,
                data: file.data,
                mimeType: "audio/mpeg",
                boundary: boundary
            )
        }
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        let data = try await performRequest(
            url: url,
            method: "POST",
            body: body,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
        
        return try decoder.decode(VoiceCloneResponse.self, from: data)
    }
    
    // MARK: - Shared Voice Library
    
    /// Browse the shared voice library.
    /// Endpoint: GET /v1/shared-voices
    func fetchSharedVoices(
        pageSize: Int = 30,
        page: Int = 0,
        search: String? = nil,
        category: String? = nil,
        gender: String? = nil,
        language: String? = nil,
        featured: Bool = false
    ) async throws -> SharedVoicesResponse {
        var components = URLComponents(string: "\(baseURL)/v1/shared-voices")!
        var queryItems = [
            URLQueryItem(name: "page_size", value: "\(min(pageSize, 100))"),
            URLQueryItem(name: "page", value: "\(page)")
        ]
        
        if let search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        if let category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }
        if let gender {
            queryItems.append(URLQueryItem(name: "gender", value: gender))
        }
        if let language {
            queryItems.append(URLQueryItem(name: "language", value: language))
        }
        if featured {
            queryItems.append(URLQueryItem(name: "featured", value: "true"))
        }
        
        components.queryItems = queryItems
        
        let data = try await performRequest(url: components.url!, method: "GET")
        return try decoder.decode(SharedVoicesResponse.self, from: data)
    }
    
    // MARK: - Private Helpers
    
    private func performRequest(
        url: URL,
        method: String,
        body: Data? = nil,
        contentType: String? = nil
    ) async throws -> Data {
        guard let apiKey else {
            throw APIError.noAPIKey
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        
        if let contentType {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        
        if let body {
            request.httpBody = body
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 401:
            throw APIError.unauthorized
        case 422:
            let errorDetail = try? decoder.decode(APIValidationError.self, from: data)
            throw APIError.validationError(errorDetail?.detail ?? "Validation error")
        case 429:
            throw APIError.rateLimited
        default:
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: errorBody)
        }
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case unauthorized
    case rateLimited
    case validationError(String)
    case httpError(statusCode: Int, body: String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your ElevenLabs API key in Settings."
        case .invalidResponse:
            return "Received an invalid response from the server."
        case .unauthorized:
            return "Authentication failed. Your API key may be invalid or expired."
        case .rateLimited:
            return "Rate limit exceeded. You may have used all your available characters for this billing period."
        case .validationError(let detail):
            return "Validation error: \(detail)"
        case .httpError(let statusCode, let body):
            return "Server error (\(statusCode)): \(body)"
        }
    }
}

// MARK: - API Validation Error Response

struct APIValidationError: Codable {
    let detail: String?
}

// MARK: - Multipart Form Data Helpers

private extension Data {
    mutating func appendMultipartField(name: String, value: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
    
    mutating func appendMultipartFile(name: String, filename: String, data: Data, mimeType: String, boundary: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }
}
