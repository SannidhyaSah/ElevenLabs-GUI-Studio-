import SwiftUI
import SwiftData
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Waveform Cache

/// In-memory cache for pre-computed waveform samples per clip.
final class WaveformCache {
    static let shared = WaveformCache()
    private var cache: [UUID: [Float]] = [:]
    private let queue = DispatchQueue(label: "waveform-cache", qos: .userInitiated)
    
    func samples(for clipId: UUID, audioData: Data?, sampleCount: Int = 200) -> [Float] {
        if let cached = cache[clipId] { return cached }
        guard let data = audioData, !data.isEmpty else {
            return Array(repeating: 0.15, count: sampleCount)
        }
        let computed = Self.extractWaveformSamples(from: data, sampleCount: sampleCount)
        cache[clipId] = computed
        return computed
    }
    
    func invalidate(_ clipId: UUID) {
        cache.removeValue(forKey: clipId)
    }
    
    /// Extract waveform samples using AVAudioFile for accurate representation.
    static func extractWaveformSamples(from data: Data, sampleCount: Int = 200) -> [Float] {
        let ext = AudioFormatDetector.fileExtension(for: data)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wf_\(UUID().uuidString).\(ext)")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        do {
            try data.write(to: tempURL)
            let audioFile = try AVAudioFile(forReading: tempURL)
            let frameCount = AVAudioFrameCount(audioFile.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(
                      pcmFormat: audioFile.processingFormat,
                      frameCapacity: frameCount
                  ) else {
                return Array(repeating: 0.2, count: sampleCount)
            }
            try audioFile.read(into: buffer)
            
            guard let channelData = buffer.floatChannelData?[0] else {
                return Array(repeating: 0.2, count: sampleCount)
            }
            
            let framesPerSample = max(1, Int(frameCount) / sampleCount)
            var samples: [Float] = []
            
            for i in 0..<sampleCount {
                let start = i * framesPerSample
                let end = min(start + framesPerSample, Int(frameCount))
                guard end > start else {
                    samples.append(0.05)
                    continue
                }
                var sum: Float = 0
                for j in start..<end {
                    sum += abs(channelData[j])
                }
                let avg = sum / Float(end - start)
                samples.append(min(1.0, avg * 2.5))
            }
            return samples
        } catch {
            // Fallback: byte-level estimation
            return fallbackWaveform(from: data, sampleCount: sampleCount)
        }
    }
    
    private static func fallbackWaveform(from data: Data, sampleCount: Int) -> [Float] {
        guard data.count > sampleCount * 2 else {
            return Array(repeating: 0.2, count: sampleCount)
        }
        let bytesPerSample = data.count / sampleCount
        var samples: [Float] = []
        data.withUnsafeBytes { buffer in
            let bytes = buffer.bindMemory(to: UInt8.self)
            for i in 0..<sampleCount {
                let offset = i * bytesPerSample
                let end = min(offset + bytesPerSample, data.count)
                var sum: Float = 0
                var count: Float = 0
                for j in stride(from: offset, to: end, by: 2) {
                    if j + 1 < data.count {
                        let value = Float(Int16(bytes[j]) | (Int16(bytes[j + 1]) << 8))
                        sum += abs(value) / 32768.0
                        count += 1
                    }
                }
                let rms = count > 0 ? sum / count : 0
                samples.append(min(1.0, rms * 3.0))
            }
        }
        return samples.isEmpty ? Array(repeating: 0.2, count: sampleCount) : samples
    }
}

// MARK: - Audio Format Detector

enum AudioFormatDetector {
    /// Detect audio file extension from raw data magic bytes.
    static func fileExtension(for data: Data) -> String {
        guard data.count >= 12 else { return "caf" }
        let bytes = [UInt8](data.prefix(12))
        
        // MP3: frame sync or ID3 tag
        if bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0 { return "mp3" }
        if bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33 { return "mp3" }
        
        // WAV / RIFF
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 { return "wav" }
        
        // AIFF / FORM
        if bytes[0] == 0x46 && bytes[1] == 0x4F && bytes[2] == 0x52 && bytes[3] == 0x4D { return "aiff" }
        
        // M4A / MP4: "ftyp" at offset 4
        if bytes[4] == 0x66 && bytes[5] == 0x74 && bytes[6] == 0x79 && bytes[7] == 0x70 { return "m4a" }
        
        // CAF
        if bytes[0] == 0x63 && bytes[1] == 0x61 && bytes[2] == 0x66 && bytes[3] == 0x66 { return "caf" }
        
        // FLAC
        if bytes[0] == 0x66 && bytes[1] == 0x4C && bytes[2] == 0x61 && bytes[3] == 0x43 { return "flac" }
        
        // OGG
        if bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53 { return "ogg" }
        
        return "caf" // safe fallback – Core Audio Format handles most things
    }
}

// MARK: - Workstation View

struct WorkstationView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \WorkstationProject.updatedAt, order: .reverse)
    private var projects: [WorkstationProject]
    
    @State private var selectedProject: WorkstationProject?
    @State private var audioService = AudioService()
    @State private var isPlayingTimeline = false
    @State private var showNewProjectDialog = false
    @State private var newProjectName = ""
    @State private var showExportDialog = false
    @State private var exportData: Data?
    @State private var selectedClip: TimelineClip?
    @State private var showFileImporter = false
    @State private var pixelsPerSecond: CGFloat = 60
    @State private var playheadPosition: TimeInterval = 0
    @State private var isExporting = false
    
    private let trackHeight: CGFloat = 80
    private let trackHeaderWidth: CGFloat = 120
    private let rulerHeight: CGFloat = 28
    
    var body: some View {
        VStack(spacing: 0) {
            if let project = selectedProject {
                projectEditorView(project)
            } else {
                projectListView
            }
        }
        .alert("New Project", isPresented: $showNewProjectDialog) {
            TextField("Project name", text: $newProjectName)
            Button("Create") {
                let project = WorkstationProject(name: newProjectName.isEmpty ? "Untitled Project" : newProjectName)
                modelContext.insert(project)
                try? modelContext.save()
                selectedProject = project
                newProjectName = ""
            }
            Button("Cancel", role: .cancel) { newProjectName = "" }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .mp3, .wav, .aiff],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                importAudioFiles(urls)
            }
        }
        .fileExporter(
            isPresented: $showExportDialog,
            document: AudioDocument(data: exportData ?? Data()),
            contentType: .audio,
            defaultFilename: "\(selectedProject?.name ?? "export").m4a"
        ) { _ in }
        .onAppear {
            consumePendingClips()
        }
        .onChange(of: appState.pendingWorkstationClips.count) { _, _ in
            consumePendingClips()
        }
    }
    
    // MARK: - Project Editor
    
    @ViewBuilder
    private func projectEditorView(_ project: WorkstationProject) -> some View {
        // Toolbar
        projectToolbar(project)
        
        Divider()
        
        if project.clips.isEmpty {
            ContentUnavailableView {
                Label("Empty Timeline", systemImage: "waveform.path")
            } description: {
                Text("Generate speech in the Playground and add clips here, or import audio files.")
            } actions: {
                Button("Go to Playground") {
                    appState.selectedTab = .playground
                }
                .buttonStyle(.borderedProminent)
                
                Button("Import Audio") {
                    showFileImporter = true
                }
            }
            .frame(maxHeight: .infinity)
        } else {
            HSplitView {
                // Timeline area
                VStack(spacing: 0) {
                    multiTrackTimeline(project)
                }
                .frame(minWidth: 500)
                
                // Clip inspector
                if let clip = selectedClip {
                    ClipInspectorView(
                        clip: clip,
                        audioService: audioService,
                        onSave: { try? modelContext.save() }
                    )
                    .frame(minWidth: 260, maxWidth: 320)
                }
            }
        }
    }
    
    // MARK: - Project Toolbar
    
    @ViewBuilder
    private func projectToolbar(_ project: WorkstationProject) -> some View {
        HStack(spacing: 10) {
            // Back button
            Button(action: { selectedProject = nil }) {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)
            .help("Back to projects")
            
            // Project name
            TextField("Project name", text: Binding(
                get: { project.name },
                set: { project.name = $0; project.updatedAt = Date() }
            ))
            .textFieldStyle(.plain)
            .font(.headline)
            .frame(maxWidth: 200)
            
            Divider().frame(height: 20)
            
            // Info
            Text("\(project.clips.count) clips · \(project.trackCount) tracks")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(AudioService.formatTime(project.totalDuration))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Zoom control
            HStack(spacing: 4) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $pixelsPerSecond, in: 20...200, step: 5)
                    .frame(width: 80)
                Image(systemName: "plus.magnifyingglass")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .help("Timeline zoom")
            
            Divider().frame(height: 20)
            
            // Import audio
            Button(action: { showFileImporter = true }) {
                Label("Import", systemImage: "square.and.arrow.down")
            }
            .controlSize(.small)
            
            // Add track
            Button(action: {
                project.addTrack()
                try? modelContext.save()
            }) {
                Label("Add Track", systemImage: "plus.rectangle.on.rectangle")
            }
            .controlSize(.small)
            
            // Split clip
            Button(action: { splitSelectedClip(project) }) {
                Label("Split", systemImage: "scissors")
            }
            .controlSize(.small)
            .disabled(selectedClip == nil)
            .help("Split selected clip at midpoint")
            
            Divider().frame(height: 20)
            
            // Play all
            Button(action: { playTimeline(project) }) {
                Label(isPlayingTimeline ? "Stop" : "Play All",
                      systemImage: isPlayingTimeline ? "stop.fill" : "play.fill")
            }
            .controlSize(.small)
            .disabled(project.clips.isEmpty)
            .keyboardShortcut(.space, modifiers: [])
            
            // Export
            Button(action: { exportTimeline(project) }) {
                if isExporting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 14, height: 14)
                } else {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(project.clips.isEmpty || isExporting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }
    
    // MARK: - Multi-Track Timeline
    
    @ViewBuilder
    private func multiTrackTimeline(_ project: WorkstationProject) -> some View {
        let totalTime = max(project.totalDuration + 5, 10)
        let contentWidth = totalTime * pixelsPerSecond
        
        HStack(spacing: 0) {
            // Fixed track headers
            VStack(spacing: 0) {
                // Ruler spacer
                Rectangle()
                    .fill(.clear)
                    .frame(width: trackHeaderWidth, height: rulerHeight)
                    .overlay(alignment: .trailing) {
                        Divider()
                    }
                
                Divider()
                
                // Track headers
                ForEach(0..<project.trackCount, id: \.self) { trackIndex in
                    TrackHeaderView(
                        trackIndex: trackIndex,
                        clipCount: project.clipsForTrack(trackIndex).count,
                        onRemove: project.trackCount > 1 ? {
                            project.removeTrack(trackIndex)
                            // Deselect if selected clip was on this track
                            if let sel = selectedClip, sel.trackIndex == trackIndex {
                                selectedClip = nil
                            }
                            try? modelContext.save()
                        } : nil
                    )
                    .frame(width: trackHeaderWidth, height: trackHeight)
                    
                    if trackIndex < project.trackCount - 1 {
                        Divider()
                    }
                }
                
                Spacer(minLength: 0)
            }
            .frame(width: trackHeaderWidth)
            .background(.bar)
            .zIndex(1)
            
            Divider()
            
            // Scrollable timeline content
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        // Time ruler
                        TimeRulerView(
                            totalTime: totalTime,
                            pixelsPerSecond: pixelsPerSecond,
                            playheadPosition: playheadPosition
                        )
                        .frame(height: rulerHeight)
                        
                        Divider()
                        
                        // Track lanes
                        ForEach(0..<project.trackCount, id: \.self) { trackIndex in
                            TrackLaneView(
                                clips: project.clipsForTrack(trackIndex),
                                trackIndex: trackIndex,
                                trackCount: project.trackCount,
                                pixelsPerSecond: pixelsPerSecond,
                                trackHeight: trackHeight,
                                totalWidth: contentWidth,
                                selectedClipId: selectedClip?.id,
                                onSelectClip: { clip in selectedClip = clip },
                                onMoveClip: { clip, newTrack, newTime in
                                    project.moveClip(clip, toTrack: newTrack, atTime: newTime)
                                    try? modelContext.save()
                                },
                                onDeleteClip: { clip in
                                    if selectedClip?.id == clip.id { selectedClip = nil }
                                    project.removeClip(clip)
                                    modelContext.delete(clip)
                                    try? modelContext.save()
                                }
                            )
                            
                            if trackIndex < project.trackCount - 1 {
                                Divider()
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .frame(width: contentWidth)
                    
                    // Playhead
                    if isPlayingTimeline {
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 1.5)
                            .offset(x: playheadPosition * pixelsPerSecond)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    // MARK: - Project List
    
    private var projectListView: some View {
        VStack(spacing: 20) {
            if projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "waveform.path")
                } description: {
                    Text("Create a project to start assembling audio clips on a timeline.")
                } actions: {
                    Button("New Project") {
                        showNewProjectDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                HStack {
                    Text("Projects")
                        .font(.title2.weight(.semibold))
                    Spacer()
                    Button("New Project") {
                        showNewProjectDialog = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                List(projects, selection: Binding(
                    get: { selectedProject?.id },
                    set: { id in selectedProject = projects.first { $0.id == id } }
                )) { project in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.name)
                                .font(.headline)
                            HStack(spacing: 8) {
                                Text("\(project.clips.count) clips")
                                Text("·")
                                Text("\(project.trackCount) tracks")
                                Text("·")
                                Text(AudioService.formatTime(project.totalDuration))
                                Text("·")
                                Text(project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Open") { selectedProject = project }
                            .controlSize(.small)
                        
                        Button(role: .destructive) {
                            modelContext.delete(project)
                            try? modelContext.save()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red.opacity(0.7))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func playTimeline(_ project: WorkstationProject) {
        if isPlayingTimeline {
            audioService.stop()
            isPlayingTimeline = false
            playheadPosition = 0
            return
        }
        
        Task {
            if let mergedData = await mergeClips(project: project) {
                do {
                    try audioService.play(data: mergedData)
                    isPlayingTimeline = true
                    // Animate playhead
                    startPlayheadTimer()
                } catch {
                    appState.errorMessage = "Failed to play timeline: \(error.localizedDescription)"
                    appState.showError = true
                }
            }
        }
    }
    
    private func startPlayheadTimer() {
        playheadPosition = 0
        Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { timer in
            if audioService.isPlaying {
                playheadPosition = audioService.currentTime
            } else {
                timer.invalidate()
                isPlayingTimeline = false
                playheadPosition = 0
            }
        }
    }
    
    private func exportTimeline(_ project: WorkstationProject) {
        isExporting = true
        Task {
            if let mergedData = await mergeClips(project: project) {
                await MainActor.run {
                    exportData = mergedData
                    showExportDialog = true
                    isExporting = false
                }
            } else {
                await MainActor.run {
                    isExporting = false
                    appState.errorMessage = "Export failed – could not merge clips."
                    appState.showError = true
                }
            }
        }
    }
    
    private func splitSelectedClip(_ project: WorkstationProject) {
        guard let clip = selectedClip else { return }
        let midpoint = clip.startTime + clip.effectiveDuration / 2
        if let (left, right) = project.splitClip(clip, atTimelineTime: midpoint) {
            modelContext.insert(left)
            modelContext.insert(right)
            modelContext.delete(clip)
            selectedClip = left
            try? modelContext.save()
        }
    }
    
    // MARK: - Merge / Export Logic (FIXED)
    
    /// Merge all project clips into a single M4A audio file.
    /// Creates one AVMutableCompositionTrack per project track for proper multi-track mixing.
    private func mergeClips(project: WorkstationProject) async -> Data? {
        let tempDir = FileManager.default.temporaryDirectory
        var tempFiles: [URL] = []
        
        defer {
            for file in tempFiles {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        // 1. Write each clip's audio data to correctly-typed temp files
        struct ClipAsset {
            let asset: AVURLAsset
            let clip: TimelineClip
        }
        
        var clipAssets: [ClipAsset] = []
        for clip in project.clips {
            guard let audioData = clip.audioData, !clip.isMuted else { continue }
            
            // FIX #1: Detect actual audio format and use correct file extension
            let ext = AudioFormatDetector.fileExtension(for: audioData)
            let tempFile = tempDir.appendingPathComponent("clip_\(clip.id.uuidString).\(ext)")
            tempFiles.append(tempFile)
            
            do {
                try audioData.write(to: tempFile)
            } catch {
                print("[Workstation] Failed to write temp file for clip \(clip.name): \(error)")
                continue
            }
            
            let asset = AVURLAsset(url: tempFile)
            clipAssets.append(ClipAsset(asset: asset, clip: clip))
        }
        
        guard !clipAssets.isEmpty else { return nil }
        
        // 2. Create AVMutableComposition
        let composition = AVMutableComposition()
        
        // 3. Create one composition track per project track
        let trackCount = project.trackCount
        var compositionTracks: [Int: AVMutableCompositionTrack] = [:]
        
        for trackIdx in 0..<trackCount {
            if let track = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) {
                compositionTracks[trackIdx] = track
            }
        }
        
        // 4. Insert each clip at its absolute startTime into the correct track
        for entry in clipAssets {
            let clip = entry.clip
            guard let compositionTrack = compositionTracks[clip.trackIndex] else {
                print("[Workstation] No composition track for index \(clip.trackIndex)")
                continue
            }
            
            do {
                let assetDuration = try await entry.asset.load(.duration)
                let assetTracks = try await entry.asset.loadTracks(withMediaType: .audio)
                guard let assetTrack = assetTracks.first else {
                    print("[Workstation] No audio track in asset for clip \(clip.name)")
                    continue
                }
                
                let assetDurationSec = CMTimeGetSeconds(assetDuration)
                let clipTrimStart = min(clip.trimStart, assetDurationSec)
                let clipTrimEnd = min(clip.trimEnd, assetDurationSec)
                let effectiveDuration = max(0, clipTrimEnd - clipTrimStart)
                
                guard effectiveDuration > 0.001 else { continue }
                
                let sourceStart = CMTimeMakeWithSeconds(clipTrimStart, preferredTimescale: 44100)
                let sourceDuration = CMTimeMakeWithSeconds(effectiveDuration, preferredTimescale: 44100)
                let sourceRange = CMTimeRange(start: sourceStart, duration: sourceDuration)
                
                // FIX #2: Insert empty time range for any gap before this clip
                let insertionTime = CMTimeMakeWithSeconds(clip.startTime, preferredTimescale: 44100)
                let currentTrackDuration = compositionTrack.timeRange.duration
                
                if CMTimeCompare(insertionTime, currentTrackDuration) > 0 {
                    let gapDuration = CMTimeSubtract(insertionTime, currentTrackDuration)
                    compositionTrack.insertEmptyTimeRange(
                        CMTimeRange(start: currentTrackDuration, duration: gapDuration)
                    )
                }
                
                try compositionTrack.insertTimeRange(
                    sourceRange,
                    of: assetTrack,
                    at: insertionTime
                )
                
                // Apply volume using AVMutableAudioMixInputParameters
                // (handled below after all clips are inserted)
                
            } catch {
                print("[Workstation] Failed to insert clip \(clip.name): \(error)")
                continue
            }
        }
        
        // 5. Build audio mix for per-clip volume
        let audioMix = AVMutableAudioMix()
        var inputParameters: [AVMutableAudioMixInputParameters] = []
        
        for (trackIdx, compositionTrack) in compositionTracks {
            let params = AVMutableAudioMixInputParameters(track: compositionTrack)
            // Set volume for each clip segment on this track
            let trackClips = clipAssets.filter { $0.clip.trackIndex == trackIdx }
            for entry in trackClips {
                let clip = entry.clip
                let start = CMTimeMakeWithSeconds(clip.startTime, preferredTimescale: 44100)
                let end = CMTimeMakeWithSeconds(clip.endTime, preferredTimescale: 44100)
                let range = CMTimeRange(start: start, duration: CMTimeSubtract(end, start))
                params.setVolumeRamp(
                    fromStartVolume: Float(clip.volume),
                    toEndVolume: Float(clip.volume),
                    timeRange: range
                )
            }
            inputParameters.append(params)
        }
        audioMix.inputParameters = inputParameters
        
        // 6. Export
        let outputURL = tempDir.appendingPathComponent("merged_\(UUID().uuidString).m4a")
        tempFiles.append(outputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            print("[Workstation] Failed to create export session")
            return nil
        }
        
        exportSession.audioMix = audioMix
        
        // FIX #3: Set explicit time range covering full composition duration
        let fullDuration = CMTimeMakeWithSeconds(project.totalDuration, preferredTimescale: 44100)
        exportSession.timeRange = CMTimeRange(start: .zero, duration: fullDuration)
        
        do {
            try await exportSession.export(to: outputURL, as: .m4a)
        } catch {
            print("[Workstation] Export failed: \(error.localizedDescription)")
            return nil
        }
        
        do {
            return try Data(contentsOf: outputURL)
        } catch {
            print("[Workstation] Failed to read exported file: \(error)")
            return nil
        }
    }
    
    // MARK: - Import
    
    private func importAudioFiles(_ urls: [URL]) {
        guard let project = selectedProject else { return }
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url) {
                var duration: TimeInterval = 0
                if let player = try? AVAudioPlayer(data: data) {
                    duration = player.duration
                }
                
                let clip = TimelineClip(
                    name: url.deletingPathExtension().lastPathComponent,
                    sourceText: "(Imported file)",
                    voiceName: "Imported",
                    modelName: "",
                    audioData: data,
                    duration: duration
                )
                project.appendClip(clip, toTrack: 0)
                modelContext.insert(clip)
            }
        }
        try? modelContext.save()
    }
    
    private func consumePendingClips() {
        guard !appState.pendingWorkstationClips.isEmpty else { return }
        
        if selectedProject == nil {
            if let first = projects.first {
                selectedProject = first
            } else {
                let project = WorkstationProject(name: "My Project")
                modelContext.insert(project)
                try? modelContext.save()
                selectedProject = project
            }
        }
        
        guard let project = selectedProject else { return }
        
        // Migrate old projects if needed
        project.migrateToAbsolutePositioning()
        
        for pending in appState.pendingWorkstationClips {
            let clip = TimelineClip(
                name: pending.name,
                sourceText: pending.sourceText,
                voiceName: pending.voiceName,
                modelName: pending.modelName,
                audioData: pending.audioData,
                duration: pending.duration
            )
            project.appendClip(clip, toTrack: 0)
            modelContext.insert(clip)
        }
        
        try? modelContext.save()
        appState.pendingWorkstationClips.removeAll()
    }
}

// MARK: - Time Ruler View

struct TimeRulerView: View {
    let totalTime: TimeInterval
    let pixelsPerSecond: CGFloat
    let playheadPosition: TimeInterval
    
    var body: some View {
        Canvas { context, size in
            let interval = rulerInterval
            var t: TimeInterval = 0
            
            while t <= totalTime {
                let x = t * pixelsPerSecond
                let isMajor = t.truncatingRemainder(dividingBy: interval * 5) < 0.001 ||
                              (interval >= 1 && Int(t) % (Int(interval) * 5) == 0)
                
                // Tick mark
                let tickHeight: CGFloat = isMajor ? 10 : 5
                let path = Path { p in
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x, y: size.height - tickHeight))
                }
                context.stroke(path, with: .color(.secondary.opacity(0.4)), lineWidth: 0.5)
                
                // Label for major ticks
                if isMajor {
                    let label = formatRulerTime(t)
                    let text = Text(label)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    context.draw(text, at: CGPoint(x: x + 2, y: size.height - 18), anchor: .leading)
                }
                
                t += interval
            }
        }
        .frame(height: 28)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private var rulerInterval: TimeInterval {
        if pixelsPerSecond > 120 { return 0.5 }
        if pixelsPerSecond > 60 { return 1.0 }
        if pixelsPerSecond > 30 { return 2.0 }
        return 5.0
    }
    
    private func formatRulerTime(_ t: TimeInterval) -> String {
        let mins = Int(t) / 60
        let secs = Int(t) % 60
        let frac = Int((t - Double(Int(t))) * 10)
        if mins > 0 {
            return String(format: "%d:%02d", mins, secs)
        }
        if pixelsPerSecond > 80 {
            return String(format: "%d.%d", secs, frac)
        }
        return "\(secs)s"
    }
}

// MARK: - Track Header View

struct TrackHeaderView: View {
    let trackIndex: Int
    let clipCount: Int
    var onRemove: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Track \(trackIndex + 1)")
                    .font(.caption.weight(.semibold))
                Spacer()
                if let onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove track")
                }
            }
            
            Text("\(clipCount) clips")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
}

// MARK: - Track Lane View

struct TrackLaneView: View {
    let clips: [TimelineClip]
    let trackIndex: Int
    let trackCount: Int
    let pixelsPerSecond: CGFloat
    let trackHeight: CGFloat
    let totalWidth: CGFloat
    let selectedClipId: UUID?
    var onSelectClip: (TimelineClip) -> Void
    var onMoveClip: (TimelineClip, Int, TimeInterval) -> Void
    var onDeleteClip: (TimelineClip) -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Track background with grid lines
            Rectangle()
                .fill(trackIndex % 2 == 0
                      ? Color(nsColor: .controlBackgroundColor).opacity(0.1)
                      : Color(nsColor: .controlBackgroundColor).opacity(0.25))
                .frame(width: totalWidth, height: trackHeight)
            
            // Clips
            ForEach(clips, id: \.id) { clip in
                DraggableClipView(
                    clip: clip,
                    isSelected: selectedClipId == clip.id,
                    pixelsPerSecond: pixelsPerSecond,
                    trackHeight: trackHeight,
                    trackCount: trackCount,
                    onSelect: { onSelectClip(clip) },
                    onMove: { newTrack, newTime in
                        onMoveClip(clip, newTrack, newTime)
                    },
                    onDelete: { onDeleteClip(clip) }
                )
            }
        }
        .frame(width: totalWidth, height: trackHeight)
    }
}

// MARK: - Draggable Clip View

struct DraggableClipView: View {
    let clip: TimelineClip
    let isSelected: Bool
    let pixelsPerSecond: CGFloat
    let trackHeight: CGFloat
    let trackCount: Int
    var onSelect: () -> Void
    var onMove: (Int, TimeInterval) -> Void
    var onDelete: () -> Void
    
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var waveformSamples: [Float] = []
    
    private var clipWidth: CGFloat {
        max(30, clip.effectiveDuration * pixelsPerSecond)
    }
    
    private var xPosition: CGFloat {
        clip.startTime * pixelsPerSecond
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Clip name + volume indicator
            HStack(spacing: 3) {
                if clip.isMuted {
                    Image(systemName: "speaker.slash.fill")
                        .font(.system(size: 7))
                        .foregroundStyle(.red.opacity(0.7))
                }
                Text(clip.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                
                Spacer(minLength: 0)
                
                if clip.volume < 0.99 {
                    Text(String(format: "%.0f%%", clip.volume * 100))
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            
            // Waveform
            TimelineWaveformView(
                samples: waveformSamples,
                color: isSelected ? Color.accentColor : Color.primary.opacity(0.35),
                isMuted: clip.isMuted
            )
            .padding(.horizontal, 4)
            .frame(height: max(20, trackHeight - 40))
            
            // Duration label
            Text(String(format: "%.2fs", clip.effectiveDuration))
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 6)
                .padding(.bottom, 2)
        }
        .frame(width: clipWidth, height: trackHeight - 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(clipBackgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.25),
                        lineWidth: isSelected ? 2 : 0.5)
        )
        .shadow(color: isDragging ? .black.opacity(0.2) : .clear, radius: 4, y: 2)
        .opacity(clip.isMuted ? 0.5 : 1.0)
        .offset(x: xPosition + dragOffset.width, y: dragOffset.height)
        .scaleEffect(isDragging ? 1.03 : 1.0)
        .zIndex(isDragging ? 100 : (isSelected ? 10 : 0))
        .onTapGesture { onSelect() }
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                    
                    // Calculate new position
                    let timeChange = Double(value.translation.width) / pixelsPerSecond
                    let trackChange = Int(round(Double(value.translation.height) / trackHeight))
                    
                    let newTime = max(0, clip.startTime + timeChange)
                    let newTrack = max(0, min(clip.trackIndex + trackChange, trackCount - 1))
                    
                    onMove(newTrack, newTime)
                    dragOffset = .zero
                }
        )
        .contextMenu {
            Button("Select") { onSelect() }
            Divider()
            Button("Mute/Unmute") { clip.isMuted.toggle() }
            Button("Reset Volume") { clip.volume = 1.0 }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .task {
            // Capture Sendable values before entering detached context
            let clipId = clip.id
            let audioData = clip.audioData
            let sampleCount = max(20, Int(clipWidth / 3))
            let samples = await Task.detached(priority: .userInitiated) {
                WaveformCache.shared.samples(
                    for: clipId,
                    audioData: audioData,
                    sampleCount: sampleCount
                )
            }.value
            waveformSamples = samples
        }
    }
    
    private var clipBackgroundColor: Color {
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        if clip.isMuted {
            return Color.gray.opacity(0.06)
        }
        return Color.primary.opacity(0.04)
    }
}

// MARK: - Timeline Waveform View

struct TimelineWaveformView: View {
    let samples: [Float]
    let color: Color
    var isMuted: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let barCount = samples.count
            let barWidth = max(1, geo.size.width / CGFloat(max(1, barCount)) - 1)
            let maxHeight = geo.size.height
            
            HStack(spacing: 1) {
                ForEach(0..<barCount, id: \.self) { i in
                    let height = max(2, CGFloat(samples[i]) * maxHeight)
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(isMuted ? Color.gray.opacity(0.2) : color)
                        .frame(width: barWidth, height: height)
                        .frame(maxHeight: maxHeight, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Clip Inspector View

struct ClipInspectorView: View {
    
    @Bindable var clip: TimelineClip
    var audioService: AudioService
    var onSave: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Image(systemName: "waveform")
                        .foregroundStyle(Color.accentColor)
                    Text("Clip Inspector")
                        .font(.headline)
                }
                
                Divider()
                
                // Name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    TextField("Clip name", text: $clip.name)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: clip.name) { _, _ in onSave() }
                }
                
                // Source info
                if !clip.sourceText.isEmpty && clip.sourceText != "(Imported file)" {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Source Text")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Text(clip.sourceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                    }
                }
                
                // Voice & Model
                HStack {
                    if !clip.voiceName.isEmpty {
                        Label(clip.voiceName, systemImage: "mic.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !clip.modelName.isEmpty {
                        Label(clip.modelName, systemImage: "cpu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Divider()
                
                // Track & Position
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Track:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text("Track \(clip.trackIndex + 1)")
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Start:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(String(format: "%.2fs", clip.startTime))
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    HStack {
                        Text("End:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(String(format: "%.2fs", clip.endTime))
                            .font(.system(.caption, design: .monospaced))
                    }
                }
                
                // Duration info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Original:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(AudioService.formatTime(clip.originalDuration))
                            .font(.system(.caption, design: .monospaced))
                    }
                    
                    HStack {
                        Text("Effective:")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Text(AudioService.formatTime(clip.effectiveDuration))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                
                Divider()
                
                // Volume
                VStack(alignment: .leading, spacing: 8) {
                    Text("Volume")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Image(systemName: clip.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundStyle(clip.isMuted ? .red : .secondary)
                            .onTapGesture {
                                clip.isMuted.toggle()
                                onSave()
                            }
                        
                        Slider(value: $clip.volume, in: 0...1, step: 0.05)
                            .onChange(of: clip.volume) { _, _ in onSave() }
                        
                        Text(String(format: "%.0f%%", clip.volume * 100))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 32)
                    }
                    
                    Toggle("Muted", isOn: $clip.isMuted)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .onChange(of: clip.isMuted) { _, _ in onSave() }
                }
                
                // Trim controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trim")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Start:")
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing)
                        Slider(value: $clip.trimStart, in: 0...clip.originalDuration, step: 0.05)
                            .onChange(of: clip.trimStart) { _, newVal in
                                if newVal >= clip.trimEnd { clip.trimStart = max(0, clip.trimEnd - 0.05) }
                                onSave()
                            }
                        Text(String(format: "%.2fs", clip.trimStart))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("End:")
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing)
                        Slider(value: $clip.trimEnd, in: 0...clip.originalDuration, step: 0.05)
                            .onChange(of: clip.trimEnd) { _, newVal in
                                if newVal <= clip.trimStart { clip.trimEnd = min(clip.originalDuration, clip.trimStart + 0.05) }
                                onSave()
                            }
                        Text(String(format: "%.2fs", clip.trimEnd))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 40)
                    }
                    
                    if clip.isTrimmed {
                        Button("Reset Trim") {
                            clip.resetTrim()
                            onSave()
                        }
                        .controlSize(.small)
                    }
                }
                
                // Gap after
                VStack(alignment: .leading, spacing: 8) {
                    Text("Gap After")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Slider(value: $clip.gapAfter, in: 0...10, step: 0.1)
                            .onChange(of: clip.gapAfter) { _, _ in onSave() }
                        Text(String(format: "%.1fs", clip.gapAfter))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 36)
                    }
                }
                
                Divider()
                
                // Playback
                Button(action: {
                    if let data = clip.audioData {
                        try? audioService.play(data: data)
                    }
                }) {
                    Label("Play Clip", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(clip.audioData == nil)
            }
            .padding(16)
        }
        .background(.bar)
    }
}

// MARK: - Notification

extension Notification.Name {
    static let addToWorkstation = Notification.Name("addToWorkstation")
}
