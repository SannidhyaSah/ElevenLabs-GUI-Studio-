import Foundation

// MARK: - AI Model

struct AIModel: Codable, Identifiable, Hashable {
    var id: String { modelId }
    
    let modelId: String
    let name: String
    let description: String?
    let canDoTextToSpeech: Bool?
    let canDoVoiceConversion: Bool?
    let canBeFinetuned: Bool?
    let canUseSpeakerBoost: Bool?
    let canUseStyle: Bool?
    let languages: [ModelLanguage]?
    let maxCharactersRequestFreeUser: Int?
    let maxCharactersRequestSubscribedUser: Int?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(modelId)
    }
    
    static func == (lhs: AIModel, rhs: AIModel) -> Bool {
        lhs.modelId == rhs.modelId
    }
}

// MARK: - Model Language

struct ModelLanguage: Codable, Hashable {
    let languageId: String?
    let name: String?
}

// MARK: - Models Response (array at top level)

typealias ModelsResponse = [AIModel]
