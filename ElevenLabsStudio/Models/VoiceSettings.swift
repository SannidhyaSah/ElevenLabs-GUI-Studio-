import Foundation

// MARK: - Voice Settings

/// Voice synthesis parameters matching the ElevenLabs API specification.
/// See: https://elevenlabs.io/docs/api-reference/text-to-speech/convert
struct VoiceSettings: Codable, Equatable {
    /// Controls voice stability/consistency. Lower = more emotional range, Higher = more monotonous.
    /// Range: 0.0 - 1.0, Default: 0.5
    var stability: Double = 0.5
    
    /// Controls how closely the AI adheres to the original voice.
    /// Range: 0.0 - 1.0, Default: 0.75
    var similarityBoost: Double = 0.75
    
    /// Controls style exaggeration. Higher values amplify the speaker's style.
    /// Setting to anything other than 0 increases latency.
    /// Range: 0.0 - 1.0, Default: 0.0
    var style: Double = 0.0
    
    /// Adjusts the speed of generated speech.
    /// Range: 0.5 - 2.0, Default: 1.0
    var speed: Double = 1.0
    
    /// Boosts similarity to the original speaker. Increases latency.
    /// Default: false
    var useSpeakerBoost: Bool = false
    
    /// Returns a new VoiceSettings with all values clamped to valid ranges.
    var clamped: VoiceSettings {
        VoiceSettings(
            stability: max(0, min(1, stability)),
            similarityBoost: max(0, min(1, similarityBoost)),
            style: max(0, min(1, style)),
            speed: max(0.5, min(2.0, speed)),
            useSpeakerBoost: useSpeakerBoost
        )
    }
    
    /// Default balanced settings.
    static let balanced = VoiceSettings()
    
    /// Expressive preset - lower stability for emotional range.
    static let expressive = VoiceSettings(
        stability: 0.3,
        similarityBoost: 0.65,
        style: 0.7,
        speed: 1.0,
        useSpeakerBoost: false
    )
    
    /// Stable preset - high consistency for narration.
    static let stable = VoiceSettings(
        stability: 0.8,
        similarityBoost: 0.9,
        style: 0.0,
        speed: 1.0,
        useSpeakerBoost: true
    )
    
    /// Fast speech preset.
    static let fastSpeech = VoiceSettings(
        stability: 0.5,
        similarityBoost: 0.75,
        style: 0.0,
        speed: 1.5,
        useSpeakerBoost: false
    )
    
    /// Slow and clear preset.
    static let slowAndClear = VoiceSettings(
        stability: 0.7,
        similarityBoost: 0.8,
        style: 0.0,
        speed: 0.8,
        useSpeakerBoost: false
    )
}

// MARK: - Output Format

/// Supported audio output formats from the ElevenLabs API.
enum OutputFormat: String, CaseIterable, Identifiable {
    case mp3_22050_32 = "mp3_22050_32"
    case mp3_44100_64 = "mp3_44100_64"
    case mp3_44100_128 = "mp3_44100_128"
    case mp3_44100_192 = "mp3_44100_192"
    case pcm_16000 = "pcm_16000"
    case pcm_22050 = "pcm_22050"
    case pcm_24000 = "pcm_24000"
    case pcm_44100 = "pcm_44100"
    case ulaw_8000 = "ulaw_8000"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .mp3_22050_32: return "MP3 22kHz 32kbps"
        case .mp3_44100_64: return "MP3 44kHz 64kbps"
        case .mp3_44100_128: return "MP3 44kHz 128kbps (Default)"
        case .mp3_44100_192: return "MP3 44kHz 192kbps (Creator+)"
        case .pcm_16000: return "PCM 16kHz"
        case .pcm_22050: return "PCM 22kHz"
        case .pcm_24000: return "PCM 24kHz"
        case .pcm_44100: return "PCM 44kHz (Pro+)"
        case .ulaw_8000: return "μ-law 8kHz (Twilio)"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .mp3_22050_32, .mp3_44100_64, .mp3_44100_128, .mp3_44100_192:
            return "mp3"
        case .pcm_16000, .pcm_22050, .pcm_24000, .pcm_44100:
            return "pcm"
        case .ulaw_8000:
            return "wav"
        }
    }
}

// MARK: - Text Normalization

enum TextNormalization: String, CaseIterable, Identifiable {
    case auto = "auto"
    case on = "on"
    case off = "off"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .auto: return "Auto"
        case .on: return "On"
        case .off: return "Off"
        }
    }
}
