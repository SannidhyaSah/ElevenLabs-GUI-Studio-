import Foundation
import SwiftData

// MARK: - Generation History

@Model
final class GenerationHistory {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""
    var voiceId: String = ""
    var voiceName: String = ""
    var modelId: String = ""
    var modelName: String = ""
    var stability: Double = 0.5
    var similarityBoost: Double = 0.75
    var style: Double = 0.0
    var speed: Double = 1.0
    var useSpeakerBoost: Bool = false
    var outputFormat: String = "mp3_44100_128"
    
    @Attribute(.externalStorage)
    var audioData: Data?
    
    init(
        text: String,
        voiceId: String,
        voiceName: String,
        modelId: String,
        modelName: String,
        voiceSettings: VoiceSettings,
        outputFormat: OutputFormat = .mp3_44100_128,
        audioData: Data? = nil
    ) {
        self.id = UUID()
        self.date = Date()
        self.text = text
        self.voiceId = voiceId
        self.voiceName = voiceName
        self.modelId = modelId
        self.modelName = modelName
        self.stability = voiceSettings.stability
        self.similarityBoost = voiceSettings.similarityBoost
        self.style = voiceSettings.style
        self.speed = voiceSettings.speed
        self.useSpeakerBoost = voiceSettings.useSpeakerBoost
        self.outputFormat = outputFormat.rawValue
        self.audioData = audioData
    }
    
    /// Reconstruct VoiceSettings from stored values.
    var voiceSettings: VoiceSettings {
        VoiceSettings(
            stability: stability,
            similarityBoost: similarityBoost,
            style: style,
            speed: speed,
            useSpeakerBoost: useSpeakerBoost
        )
    }
    
    /// Whether audio data is available for playback.
    var hasAudio: Bool {
        audioData != nil && !(audioData?.isEmpty ?? true)
    }
    
    /// Formatted date string for display.
    var formattedDate: String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
    
    /// Truncated text preview for list display.
    var textPreview: String {
        if text.count > 100 {
            return String(text.prefix(100)) + "..."
        }
        return text
    }
}
