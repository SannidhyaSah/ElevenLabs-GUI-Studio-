import Foundation
import SwiftData

// MARK: - Voice Preset

@Model
final class VoicePreset {
    var id: UUID = UUID()
    var name: String = ""
    var stability: Double = 0.5
    var similarityBoost: Double = 0.75
    var style: Double = 0.0
    var speed: Double = 1.0
    var useSpeakerBoost: Bool = false
    var isDefault: Bool = false
    var createdAt: Date = Date()
    
    init(
        name: String,
        stability: Double = 0.5,
        similarityBoost: Double = 0.75,
        style: Double = 0.0,
        speed: Double = 1.0,
        useSpeakerBoost: Bool = false,
        isDefault: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.stability = stability
        self.similarityBoost = similarityBoost
        self.style = style
        self.speed = speed
        self.useSpeakerBoost = useSpeakerBoost
        self.isDefault = isDefault
        self.createdAt = Date()
    }
    
    /// Convert to VoiceSettings.
    var voiceSettings: VoiceSettings {
        VoiceSettings(
            stability: stability,
            similarityBoost: similarityBoost,
            style: style,
            speed: speed,
            useSpeakerBoost: useSpeakerBoost
        )
    }
    
    /// Update from VoiceSettings.
    func update(from settings: VoiceSettings) {
        stability = settings.stability
        similarityBoost = settings.similarityBoost
        style = settings.style
        speed = settings.speed
        useSpeakerBoost = settings.useSpeakerBoost
    }
    
    /// Default presets shipped with the app.
    static let defaults: [(String, VoiceSettings)] = [
        ("Balanced", .balanced),
        ("Expressive", .expressive),
        ("Stable", .stable),
        ("Fast Speech", .fastSpeech),
        ("Slow & Clear", .slowAndClear)
    ]
}
