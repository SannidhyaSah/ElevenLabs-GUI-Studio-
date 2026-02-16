import SwiftUI
import SwiftData
import AVFoundation

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
    
    var body: some View {
        VStack(spacing: 0) {
            if let project = selectedProject {
                // Project toolbar
                HStack(spacing: 12) {
                    // Project name
                    TextField("Project name", text: Binding(
                        get: { project.name },
                        set: { project.name = $0; project.updatedAt = Date() }
                    ))
                    .textFieldStyle(.plain)
                    .font(.headline)
                    .frame(maxWidth: 250)
                    
                    Divider().frame(height: 20)
                    
                    // Clip count & duration
                    Text("\(project.clips.count) clips")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .foregroundStyle(.quaternary)
                    
                    Text(AudioService.formatTime(project.totalDuration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    // Import audio file
                    Button(action: { showFileImporter = true }) {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                    .controlSize(.small)
                    .help("Import an audio file")
                    
                    Divider().frame(height: 20)
                    
                    // Play full timeline
                    Button(action: { playTimeline(project) }) {
                        Label(isPlayingTimeline ? "Stop" : "Play All", 
                              systemImage: isPlayingTimeline ? "stop.fill" : "play.fill")
                    }
                    .controlSize(.small)
                    .disabled(project.clips.isEmpty)
                    
                    // Export
                    Button(action: { exportTimeline(project) }) {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(project.clips.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
                
                Divider()
                
                // Timeline area
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
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Timeline + clip inspector
                    HSplitView {
                        // Timeline
                        ScrollView(.horizontal, showsIndicators: true) {
                            TimelineTrackView(
                                clips: project.sortedClips,
                                selectedClip: $selectedClip,
                                onReorder: { from, to in
                                    project.moveClip(from: from, to: to)
                                    try? modelContext.save()
                                },
                                onDelete: { clip in
                                    project.removeClip(clip)
                                    modelContext.delete(clip)
                                    try? modelContext.save()
                                    if selectedClip?.id == clip.id {
                                        selectedClip = nil
                                    }
                                }
                            )
                            .frame(minHeight: 120)
                            .padding()
                        }
                        .frame(minWidth: 400)
                        
                        // Clip inspector (right panel)
                        if let clip = selectedClip {
                            ClipInspectorView(
                                clip: clip,
                                audioService: audioService,
                                onSave: {
                                    try? modelContext.save()
                                }
                            )
                            .frame(minWidth: 260, maxWidth: 320)
                        }
                    }
                }
            } else {
                // Project list / empty state
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
                        // Project header
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
                        
                        // Project list
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
                                        Text("•")
                                        Text(AudioService.formatTime(project.totalDuration))
                                        Text("•")
                                        Text(project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    selectedProject = project
                                }) {
                                    Text("Open")
                                }
                                .controlSize(.small)
                                
                                Button(role: .destructive, action: {
                                    modelContext.delete(project)
                                    try? modelContext.save()
                                }) {
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
    
    // MARK: - Actions
    
    private func playTimeline(_ project: WorkstationProject) {
        if isPlayingTimeline {
            audioService.stop()
            isPlayingTimeline = false
            return
        }
        
        // Merge clips and play
        Task {
            if let mergedData = await mergeClips(project.sortedClips) {
                do {
                    try audioService.play(data: mergedData)
                    isPlayingTimeline = true
                } catch {
                    appState.errorMessage = "Failed to play timeline: \(error.localizedDescription)"
                    appState.showError = true
                }
            }
        }
    }
    
    private func exportTimeline(_ project: WorkstationProject) {
        Task {
            if let mergedData = await mergeClips(project.sortedClips) {
                exportData = mergedData
                showExportDialog = true
            }
        }
    }
    
    private func mergeClips(_ clips: [TimelineClip]) async -> Data? {
        let tempDir = FileManager.default.temporaryDirectory
        var tempFiles: [URL] = []
        
        defer {
            // Clean up temp files
            for file in tempFiles {
                try? FileManager.default.removeItem(at: file)
            }
        }
        
        // 1. Write each clip's audio data to a temporary file
        var clipAssets: [(asset: AVURLAsset, trimStart: TimeInterval, trimEnd: TimeInterval, gapAfter: TimeInterval)] = []
        for (index, clip) in clips.enumerated() {
            guard let audioData = clip.audioData else { continue }
            let tempFile = tempDir.appendingPathComponent("clip_\(index)_\(UUID().uuidString).m4a")
            tempFiles.append(tempFile)
            do {
                try audioData.write(to: tempFile)
            } catch {
                print("Failed to write temp file for clip \(index): \(error)")
                continue
            }
            let asset = AVURLAsset(url: tempFile)
            clipAssets.append((asset: asset, trimStart: clip.trimStart, trimEnd: clip.trimEnd, gapAfter: clip.gapAfter))
        }
        
        guard !clipAssets.isEmpty else { return nil }
        
        // 2. Create AVMutableComposition with an audio track
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            print("Failed to create composition audio track")
            return nil
        }
        
        // 3. Insert each clip's audio at the correct time offset
        var insertionTime = CMTime.zero
        for entry in clipAssets {
            do {
                let duration = try await entry.asset.load(.duration)
                let assetTracks = try await entry.asset.loadTracks(withMediaType: .audio)
                guard let assetTrack = assetTracks.first else {
                    print("No audio track found in asset")
                    continue
                }
                
                let assetDuration = CMTimeGetSeconds(duration)
                let clipTrimStart = min(entry.trimStart, assetDuration)
                let clipTrimEnd = min(entry.trimEnd, assetDuration)
                let effectiveDuration = max(0, clipTrimEnd - clipTrimStart)
                
                let startTime = CMTimeMakeWithSeconds(clipTrimStart, preferredTimescale: 44100)
                let clipDuration = CMTimeMakeWithSeconds(effectiveDuration, preferredTimescale: 44100)
                let timeRange = CMTimeRange(start: startTime, duration: clipDuration)
                
                try compositionTrack.insertTimeRange(timeRange, of: assetTrack, at: insertionTime)
                
                // Advance insertion point by clip duration + gap
                insertionTime = CMTimeAdd(insertionTime, clipDuration)
                if entry.gapAfter > 0 {
                    let gapDuration = CMTimeMakeWithSeconds(entry.gapAfter, preferredTimescale: 44100)
                    insertionTime = CMTimeAdd(insertionTime, gapDuration)
                }
            } catch {
                print("Failed to insert clip into composition: \(error)")
                continue
            }
        }
        
        // 4. Export using AVAssetExportSession to produce a valid M4A file
        let outputURL = tempDir.appendingPathComponent("merged_\(UUID().uuidString).m4a")
        tempFiles.append(outputURL)
        
        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            print("Failed to create export session")
            return nil
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            print("Export failed: \(exportSession.error?.localizedDescription ?? "unknown error")")
            return nil
        }
        
        // 5. Return the exported file's Data
        do {
            return try Data(contentsOf: outputURL)
        } catch {
            print("Failed to read exported file: \(error)")
            return nil
        }
    }
    
    private func importAudioFiles(_ urls: [URL]) {
        guard let project = selectedProject else { return }
        
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url) {
                // Get duration
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
                project.appendClip(clip)
                modelContext.insert(clip)
            }
        }
        try? modelContext.save()
    }
    
    private func consumePendingClips() {
        guard !appState.pendingWorkstationClips.isEmpty else { return }
        
        // Create project if none selected
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
        
        for pending in appState.pendingWorkstationClips {
            let clip = TimelineClip(
                name: pending.name,
                sourceText: pending.sourceText,
                voiceName: pending.voiceName,
                modelName: pending.modelName,
                audioData: pending.audioData,
                duration: pending.duration
            )
            project.appendClip(clip)
            modelContext.insert(clip)
        }
        
        try? modelContext.save()
        appState.pendingWorkstationClips.removeAll()
    }
}

// MARK: - Timeline Track View

struct TimelineTrackView: View {
    
    let clips: [TimelineClip]
    @Binding var selectedClip: TimelineClip?
    var onReorder: (Int, Int) -> Void
    var onDelete: (TimelineClip) -> Void
    
    private let pixelsPerSecond: CGFloat = 40
    private let clipHeight: CGFloat = 80
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(Array(clips.enumerated()), id: \.element.id) { index, clip in
                HStack(spacing: 0) {
                    // Clip block
                    TimelineClipBlock(
                        clip: clip,
                        isSelected: selectedClip?.id == clip.id,
                        pixelsPerSecond: pixelsPerSecond,
                        height: clipHeight,
                        onTap: { selectedClip = clip },
                        onDelete: { onDelete(clip) }
                    )
                    
                    // Gap indicator
                    if clip.gapAfter > 0 {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: max(4, clip.gapAfter * pixelsPerSecond), height: clipHeight * 0.3)
                            .overlay {
                                Text(String(format: "%.1fs", clip.gapAfter))
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                    }
                    
                    // Small gap between clips for visual separation
                    if index < clips.count - 1 && clip.gapAfter == 0 {
                        Rectangle()
                            .fill(.clear)
                            .frame(width: 2)
                    }
                }
            }
            
            Spacer(minLength: 40)
        }
    }
}

// MARK: - Timeline Clip Block

struct TimelineClipBlock: View {
    
    let clip: TimelineClip
    let isSelected: Bool
    let pixelsPerSecond: CGFloat
    let height: CGFloat
    var onTap: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        let width: CGFloat = max(60, clip.effectiveDuration * pixelsPerSecond)
        let barColor: Color = isSelected ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.2)
        let barCount: Int = max(1, Int(width / 4))
        
        VStack(alignment: .leading, spacing: 4) {
            // Clip name
            Text(clip.name)
                .font(.caption2.weight(.medium))
                .lineLimit(1)
            
            // Mini waveform placeholder
            HStack(spacing: 1) {
                ForEach(0..<barCount, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor)
                        .frame(width: 2, height: CGFloat.random(in: 8...max(10, height * 0.5)))
                }
            }
            .frame(height: height * 0.5)
            
            // Duration
            Text(AudioService.formatTime(clip.effectiveDuration))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(width: width, height: height)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
        )
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button("Delete", role: .destructive, action: onDelete)
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
                
                // Duration info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Timing")
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
                
                // Trim controls
                VStack(alignment: .leading, spacing: 8) {
                    Text("Trim")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text("Start:")
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing)
                        Slider(value: $clip.trimStart, in: 0...clip.originalDuration, step: 0.1)
                            .onChange(of: clip.trimStart) { _, newVal in
                                if newVal >= clip.trimEnd { clip.trimStart = max(0, clip.trimEnd - 0.1) }
                                onSave()
                            }
                        Text(String(format: "%.1fs", clip.trimStart))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 36)
                    }
                    
                    HStack {
                        Text("End:")
                            .font(.caption)
                            .frame(width: 40, alignment: .trailing)
                        Slider(value: $clip.trimEnd, in: 0...clip.originalDuration, step: 0.1)
                            .onChange(of: clip.trimEnd) { _, newVal in
                                if newVal <= clip.trimStart { clip.trimEnd = min(clip.originalDuration, clip.trimStart + 0.1) }
                                onSave()
                            }
                        Text(String(format: "%.1fs", clip.trimEnd))
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 36)
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
                        Slider(value: $clip.gapAfter, in: 0...5, step: 0.1)
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
