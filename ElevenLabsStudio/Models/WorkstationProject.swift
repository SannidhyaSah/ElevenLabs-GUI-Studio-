import Foundation
import SwiftData

// MARK: - Workstation Project

@Model
final class WorkstationProject {
    var id: UUID = UUID()
    var name: String = "Untitled Project"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    @Relationship(deleteRule: .cascade)
    var clips: [TimelineClip] = []
    
    init(name: String = "Untitled Project") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Clips sorted by their position on the timeline.
    var sortedClips: [TimelineClip] {
        clips.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    /// Total duration of all clips plus gaps.
    var totalDuration: TimeInterval {
        sortedClips.reduce(0) { total, clip in
            total + clip.effectiveDuration + clip.gapAfter
        }
    }
    
    /// Add a clip to the end of the timeline.
    func appendClip(_ clip: TimelineClip) {
        clip.orderIndex = (clips.map(\.orderIndex).max() ?? -1) + 1
        clips.append(clip)
        updatedAt = Date()
    }
    
    /// Reorder clips by moving from one index to another.
    func moveClip(from source: Int, to destination: Int) {
        var sorted = sortedClips
        let clip = sorted.remove(at: source)
        sorted.insert(clip, at: destination)
        for (index, c) in sorted.enumerated() {
            c.orderIndex = index
        }
        updatedAt = Date()
    }
    
    /// Remove a clip from the project.
    func removeClip(_ clip: TimelineClip) {
        clips.removeAll { $0.id == clip.id }
        // Re-index remaining clips
        for (index, c) in sortedClips.enumerated() {
            c.orderIndex = index
        }
        updatedAt = Date()
    }
}

// MARK: - Timeline Clip

@Model
final class TimelineClip {
    var id: UUID = UUID()
    var name: String = ""
    var orderIndex: Int = 0
    
    /// The original text used to generate this clip.
    var sourceText: String = ""
    
    /// Voice and model info for reference.
    var voiceName: String = ""
    var modelName: String = ""
    
    /// Trim points (in seconds from start of original audio).
    var trimStart: TimeInterval = 0
    var trimEnd: TimeInterval = 0
    
    /// Gap (silence) after this clip in seconds.
    var gapAfter: TimeInterval = 0
    
    /// The full original audio data.
    @Attribute(.externalStorage)
    var audioData: Data?
    
    /// Duration of the original audio.
    var originalDuration: TimeInterval = 0
    
    var createdAt: Date = Date()
    
    init(
        name: String,
        sourceText: String = "",
        voiceName: String = "",
        modelName: String = "",
        audioData: Data?,
        duration: TimeInterval
    ) {
        self.id = UUID()
        self.name = name
        self.sourceText = sourceText
        self.voiceName = voiceName
        self.modelName = modelName
        self.audioData = audioData
        self.originalDuration = duration
        self.trimStart = 0
        self.trimEnd = duration
        self.gapAfter = 0
        self.createdAt = Date()
    }
    
    /// The effective duration after trimming.
    var effectiveDuration: TimeInterval {
        max(0, trimEnd - trimStart)
    }
    
    /// Whether the clip has been trimmed from its original.
    var isTrimmed: Bool {
        trimStart > 0.01 || abs(trimEnd - originalDuration) > 0.01
    }
    
    /// Reset trim to full original duration.
    func resetTrim() {
        trimStart = 0
        trimEnd = originalDuration
    }
}
