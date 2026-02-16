import Foundation

// MARK: - Voice

struct Voice: Codable, Identifiable, Hashable {
    var id: String { voiceId }
    
    let voiceId: String
    let name: String
    let description: String?
    let category: String?
    let voiceType: String?
    let highQualityBaseModelIds: [String]?
    let verifiedLanguages: [VerifiedLanguage]?
    let isOwner: Bool?
    let isLegacy: Bool?
    let isMixed: Bool?
    let createdAtUnix: Int?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(voiceId)
    }
    
    static func == (lhs: Voice, rhs: Voice) -> Bool {
        lhs.voiceId == rhs.voiceId
    }
}

// MARK: - Verified Language

struct VerifiedLanguage: Codable, Hashable {
    let language: String?
    let modelId: String?
    let accent: String?
    let locale: String?
    let previewUrl: String?
}

// MARK: - Voices Response

struct VoicesResponse: Codable {
    let voices: [Voice]
    let hasMore: Bool?
    let totalCount: Int?
    let nextPageToken: String?
}

// MARK: - Shared Voice (Voice Library)

struct SharedVoice: Codable, Identifiable, Hashable {
    var id: String { voiceId }
    
    let voiceId: String
    let name: String
    let category: String?
    let description: String?
    let languages: [SharedVoiceLanguage]?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(voiceId)
    }
    
    static func == (lhs: SharedVoice, rhs: SharedVoice) -> Bool {
        lhs.voiceId == rhs.voiceId
    }
}

struct SharedVoiceLanguage: Codable, Hashable {
    let language: String?
    let modelId: String?
    let accent: String?
    let locale: String?
    let previewUrl: String?
}

struct SharedVoicesResponse: Codable {
    let voices: [SharedVoice]
}

// MARK: - Voice Clone Response

struct VoiceCloneResponse: Codable {
    let voiceId: String
    let requiresVerification: Bool
}
