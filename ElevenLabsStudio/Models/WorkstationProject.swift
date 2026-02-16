import Foundation
import SwiftData

// MARK: - Workstation Project

@Model
final class WorkstationProject {
    var id: UUID = UUID()
    var name: String = "Untitled Project"
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    /// Number of tracks in the project (minimum 1).
    var numberOfTracks: Int = 1
    
    @Relationship(deleteRule: .cascade)
    var clips: [TimelineClip] = []
    
    init(name: String = "Untitled Project") {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.numberOfTracks = 1
    }
    
    // MARK: - Track Management
    
    /// Effective track count (max of stored value and highest clip track).
    var trackCount: Int {
        max(numberOfTracks, (clips.map(\.trackIndex).max() ?? 0) + 1)
    }
    
    /// Add a new empty track.
    func addTrack() {
        numberOfTracks = trackCount + 1
        updatedAt = Date()
    }
    
    /// Remove a track and shift clips on higher tracks down.
    func removeTrack(_ index: Int) {
        guard trackCount > 1 else { return }
        clips.removeAll { $0.trackIndex == index }
        for clip in clips where clip.trackIndex > index {
            clip.trackIndex -= 1
        }
        numberOfTracks = max(1, numberOfTracks - 1)
        updatedAt = Date()
    }
    
    // MARK: - Clip Queries
    
    /// Clips for a specific track, sorted by startTime.
    func clipsForTrack(_ trackIndex: Int) -> [TimelineClip] {
        clips.filter { $0.trackIndex == trackIndex }
             .sorted { $0.startTime < $1.startTime }
    }
    
    /// All clips sorted by track then start time.
    var sortedClips: [TimelineClip] {
        clips.sorted {
            if $0.trackIndex != $1.trackIndex {
                return $0.trackIndex < $1.trackIndex
            }
            return $0.startTime < $1.startTime
        }
    }
    
    /// Total timeline duration across all tracks.
    var totalDuration: TimeInterval {
        clips.map { $0.startTime + $0.effectiveDuration }.max() ?? 0
    }
    
    // MARK: - Clip Manipulation
    
    /// Add a clip to the end of a specific track.
    func appendClip(_ clip: TimelineClip, toTrack trackIndex: Int = 0) {
        let trackClips = clipsForTrack(trackIndex)
        let endTime = trackClips.map { $0.startTime + $0.effectiveDuration + $0.gapAfter }.max() ?? 0
        clip.trackIndex = trackIndex
        clip.startTime = endTime
        clip.orderIndex = (clips.map(\.orderIndex).max() ?? -1) + 1
        clips.append(clip)
        if trackIndex >= numberOfTracks {
            numberOfTracks = trackIndex + 1
        }
        updatedAt = Date()
    }
    
    /// Legacy append – adds to track 0.
    func appendClip(_ clip: TimelineClip) {
        appendClip(clip, toTrack: 0)
    }
    
    /// Move a clip to a new track and/or absolute time.
    func moveClip(_ clip: TimelineClip, toTrack: Int, atTime: TimeInterval) {
        clip.trackIndex = max(0, min(toTrack, trackCount - 1))
        clip.startTime = max(0, atTime)
        updatedAt = Date()
    }
    
    /// Remove a clip from the project.
    func removeClip(_ clip: TimelineClip) {
        clips.removeAll { $0.id == clip.id }
        updatedAt = Date()
    }
    
    /// Split a clip at an absolute timeline time.
    /// Returns the two new clips (left, right) or nil if the split point is invalid.
    @discardableResult
    func splitClip(_ clip: TimelineClip, atTimelineTime splitTime: TimeInterval) -> (TimelineClip, TimelineClip)? {
        let relativeTime = splitTime - clip.startTime
        guard relativeTime > 0.01, relativeTime < clip.effectiveDuration - 0.01 else { return nil }
        
        let splitPointInSource = clip.trimStart + relativeTime
        
        // Left half
        let clipA = TimelineClip(
            name: clip.name + " (L)",
            sourceText: clip.sourceText,
            voiceName: clip.voiceName,
            modelName: clip.modelName,
            audioData: clip.audioData,
            duration: clip.originalDuration,
            trackIndex: clip.trackIndex,
            startTime: clip.startTime
        )
        clipA.trimStart = clip.trimStart
        clipA.trimEnd = splitPointInSource
        clipA.volume = clip.volume
        clipA.orderIndex = clip.orderIndex
        
        // Right half
        let clipB = TimelineClip(
            name: clip.name + " (R)",
            sourceText: clip.sourceText,
            voiceName: clip.voiceName,
            modelName: clip.modelName,
            audioData: clip.audioData,
            duration: clip.originalDuration,
            trackIndex: clip.trackIndex,
            startTime: clip.startTime + relativeTime
        )
        clipB.trimStart = splitPointInSource
        clipB.trimEnd = clip.trimEnd
        clipB.volume = clip.volume
        clipB.gapAfter = clip.gapAfter
        clipB.orderIndex = clip.orderIndex + 1
        
        clips.append(clipA)
        clips.append(clipB)
        removeClip(clip)
        
        updatedAt = Date()
        return (clipA, clipB)
    }
    
    /// Reorder clips on track 0 (legacy). Updates startTime accordingly.
    func moveClip(from source: Int, to destination: Int) {
        let trackClips = clipsForTrack(0)
        guard source < trackClips.count else { return }
        var mutable = trackClips
        let clip = mutable.remove(at: source)
        let dest = min(destination, mutable.count)
        mutable.insert(clip, at: dest)
        
        var currentTime: TimeInterval = 0
        for (index, c) in mutable.enumerated() {
            c.orderIndex = index
            c.startTime = currentTime
            currentTime += c.effectiveDuration + c.gapAfter
        }
        updatedAt = Date()
    }
    
    /// Migrate old sequential-only clips to absolute positioning.
    /// Called once when a project is opened if all track-0 clips have startTime == 0.
    func migrateToAbsolutePositioning() {
        let track0Clips = clips
            .filter { $0.trackIndex == 0 }
            .sorted { $0.orderIndex < $1.orderIndex }
        
        let needsMigration = track0Clips.count > 1 && track0Clips.allSatisfy { $0.startTime == 0 }
        guard needsMigration else { return }
        
        var currentTime: TimeInterval = 0
        for clip in track0Clips {
            clip.startTime = currentTime
            currentTime += clip.effectiveDuration + clip.gapAfter
        }
    }
}

// MARK: - Timeline Clip

@Model
final class TimelineClip {
    var id: UUID = UUID()
    var name: String = ""
    var orderIndex: Int = 0
    
    /// Track index (layer) this clip belongs to.
    var trackIndex: Int = 0
    
    /// Absolute start time on the timeline (seconds).
    var startTime: TimeInterval = 0
    
    /// Volume level for this clip (0.0 – 1.0).
    var volume: Double = 1.0
    
    /// Whether this clip is muted during playback/export.
    var isMuted: Bool = false
    
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
        duration: TimeInterval,
        trackIndex: Int = 0,
        startTime: TimeInterval = 0
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
        self.trackIndex = trackIndex
        self.startTime = startTime
        self.volume = 1.0
        self.isMuted = false
        self.createdAt = Date()
    }
    
    /// The effective duration after trimming.
    var effectiveDuration: TimeInterval {
        max(0, trimEnd - trimStart)
    }
    
    /// The end time of this clip on the timeline.
    var endTime: TimeInterval {
        startTime + effectiveDuration
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
