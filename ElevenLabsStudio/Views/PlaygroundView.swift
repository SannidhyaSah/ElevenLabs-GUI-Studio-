import SwiftUI
import SwiftData
import AVFoundation

// MARK: - Playground View

struct PlaygroundView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @State private var text = ""
    @State private var selectedVoiceId: String?
    @State private var selectedModelId: String?
    @State private var voiceSettings = VoiceSettings.balanced
    @State private var selectedOutputFormat: OutputFormat = .mp3_44100_128
    @State private var showParametersPanel = true
    @State private var breakDuration: Double = 1.0
    
    // Generation state
    @State private var generateCount: Int = 1  // 1 or 2
    @State private var takes: [GeneratedTake] = []
    @State private var selectedTakeIndex: Int?
    @State private var showExportDialog = false
    @State private var exportData: Data?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Voice & Model selectors
                    HStack(spacing: 12) {
                        SelectorCard(
                            title: "Voice",
                            icon: "mic.fill",
                            isLoading: appState.isLoadingVoices
                        ) {
                            HStack {
                                Picker("", selection: $selectedVoiceId) {
                                    Text("Select a voice...").tag(nil as String?)
                                    ForEach(appState.voices) { voice in
                                        Text(voice.name).tag(voice.voiceId as String?)
                                    }
                                }
                                .labelsHidden()
                                
                                Button(action: { Task { await appState.loadVoices() } }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .disabled(appState.isLoadingVoices)
                            }
                        }
                        
                        SelectorCard(
                            title: "Model",
                            icon: "cpu",
                            isLoading: appState.isLoadingModels
                        ) {
                            HStack {
                                Picker("", selection: $selectedModelId) {
                                    Text("Select a model...").tag(nil as String?)
                                    ForEach(appState.models) { model in
                                        Text(model.name).tag(model.modelId as String?)
                                    }
                                }
                                .labelsHidden()
                                
                                Button(action: { Task { await appState.loadModels() } }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .disabled(appState.isLoadingModels)
                            }
                        }
                        
                        SelectorCard(title: "Format", icon: "waveform") {
                            Picker("", selection: $selectedOutputFormat) {
                                ForEach(OutputFormat.allCases) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    
                    // Text input
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Text", systemImage: "text.alignleft")
                                .font(.subheadline.weight(.semibold))
                            
                            Spacer()
                            
                            Text("\(text.count)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.quaternary, in: Capsule())
                            
                            // Break tag tool
                            HStack(spacing: 5) {
                                Image(systemName: "pause.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                TextField("", value: $breakDuration, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 44)
                                
                                Text("s")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                
                                Button(action: insertBreakTag) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                                .help("Insert pause break tag")
                            }
                        }
                        
                        TextEditor(text: $text)
                            .font(.body)
                            .frame(minHeight: 120, maxHeight: 260)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.background)
                                    .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(.quaternary, lineWidth: 1)
                            )
                            .overlay(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("Enter text to convert to speech...")
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 20)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    
                    // Action bar
                    HStack(spacing: 12) {
                        Button(action: clearAll) {
                            Label("New", systemImage: "doc")
                        }
                        .keyboardShortcut("n", modifiers: .command)
                        
                        Spacer()
                        
                        if !appState.isAPIKeyValid {
                            Label("Add API key in Settings", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        // Generate count picker
                        Picker("Takes", selection: $generateCount) {
                            Text("1x").tag(1)
                            Text("2x").tag(2)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 100)
                        .help("Number of takes to generate for comparison")
                        
                        Button(action: generateSpeech) {
                            HStack(spacing: 8) {
                                if appState.isGenerating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "waveform.badge.plus")
                                }
                                Text(appState.isGenerating
                                     ? "Generating..."
                                     : generateCount == 1 ? "Generate" : "Generate 2 Takes")
                                    .fontWeight(.medium)
                            }
                            .frame(minWidth: 140)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentColor)
                        .controlSize(.large)
                        .disabled(text.isEmpty || selectedVoiceId == nil || selectedModelId == nil || appState.isGenerating || !appState.isAPIKeyValid)
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                    
                    // Generated takes
                    if !takes.isEmpty {
                        VStack(spacing: 12) {
                            if takes.count > 1 {
                                // A/B comparison header
                                HStack {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .foregroundStyle(Color.accentColor)
                                    Text("Compare Takes")
                                        .font(.subheadline.weight(.semibold))
                                    Text("— pick the best one")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                            
                            ForEach(Array(takes.enumerated()), id: \.element.id) { index, take in
                                TakeView(
                                    take: take,
                                    label: takes.count > 1 ? "Take \(["A", "B"][index])" : nil,
                                    isSelected: selectedTakeIndex == index,
                                    onSelect: { selectedTakeIndex = index },
                                    onAddToWorkstation: { addToWorkstation(take) },
                                    onSave: {
                                        exportData = take.audioData
                                        showExportDialog = true
                                    }
                                )
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .push(from: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding(20)
            }
            
            // Collapsible parameters panel
            VStack(spacing: 0) {
                Divider()
                
                Button(action: {
                    withAnimation(.spring(duration: 0.3)) {
                        showParametersPanel.toggle()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                        Text("Voice Parameters")
                            .font(.caption.weight(.medium))
                        Spacer()
                        Image(systemName: showParametersPanel ? "chevron.down" : "chevron.up")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                
                if showParametersPanel {
                    VoiceParameterSliders(
                        settings: $voiceSettings,
                        onTestSettings: testSettings
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .background(.bar)
        }
        .animation(.spring(duration: 0.3), value: takes.count)
        .fileExporter(
            isPresented: $showExportDialog,
            document: AudioDocument(data: exportData ?? Data()),
            contentType: .audio,
            defaultFilename: "elevenlabs-output.\(selectedOutputFormat.fileExtension)"
        ) { _ in }
        .onAppear {
            if selectedVoiceId == nil, let first = appState.voices.first {
                selectedVoiceId = first.voiceId
            }
            if selectedModelId == nil, let first = appState.models.first {
                selectedModelId = first.modelId
            }
        }
        .onChange(of: appState.voices) { _, voices in
            if selectedVoiceId == nil, let first = voices.first {
                selectedVoiceId = first.voiceId
            }
        }
        .onChange(of: appState.models) { _, models in
            if selectedModelId == nil, let first = models.first {
                selectedModelId = first.modelId
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newGeneration)) { _ in clearAll() }
        .onReceive(NotificationCenter.default.publisher(for: .generateSpeech)) { _ in generateSpeech() }
        .onReceive(NotificationCenter.default.publisher(for: .saveAudio)) { _ in
            if let take = selectedTake {
                exportData = take.audioData
                showExportDialog = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loadFromHistory)) { notification in
            if let userInfo = notification.userInfo {
                if let historyText = userInfo["text"] as? String { text = historyText }
                if let voiceId = userInfo["voiceId"] as? String { selectedVoiceId = voiceId }
                if let modelId = userInfo["modelId"] as? String { selectedModelId = modelId }
            }
        }
    }
    
    private var selectedTake: GeneratedTake? {
        guard let index = selectedTakeIndex, index < takes.count else { return takes.first }
        return takes[index]
    }
    
    // MARK: - Actions
    
    private func generateSpeech() {
        guard !text.isEmpty,
              let voiceId = selectedVoiceId,
              let modelId = selectedModelId else { return }
        
        takes = []
        selectedTakeIndex = nil
        
        Task {
            do {
                // Generate the requested number of takes
                for i in 0..<generateCount {
                    let audioData = try await appState.generateSpeech(
                        text: text,
                        voiceId: voiceId,
                        modelId: modelId,
                        voiceSettings: voiceSettings,
                        outputFormat: selectedOutputFormat
                    )
                    
                    // Get duration
                    var duration: TimeInterval = 0
                    if let player = try? AVAudioPlayer(data: audioData) {
                        duration = player.duration
                    }
                    
                    let voiceName = appState.voices.first(where: { $0.voiceId == voiceId })?.name ?? "Unknown"
                    let modelName = appState.models.first(where: { $0.modelId == modelId })?.name ?? "Unknown"
                    
                    let take = GeneratedTake(
                        audioData: audioData,
                        duration: duration,
                        voiceName: voiceName,
                        modelName: modelName,
                        label: generateCount > 1 ? "Take \(["A", "B"][i])" : "Generated"
                    )
                    
                    await MainActor.run {
                        takes.append(take)
                        if i == 0 { selectedTakeIndex = 0 }
                    }
                }
                
                // Save to history (first take)
                if let firstTake = takes.first {
                    let historyItem = GenerationHistory(
                        text: text,
                        voiceId: voiceId,
                        voiceName: firstTake.voiceName,
                        modelId: modelId,
                        modelName: firstTake.modelName,
                        voiceSettings: voiceSettings,
                        outputFormat: selectedOutputFormat,
                        audioData: firstTake.audioData
                    )
                    modelContext.insert(historyItem)
                    try? modelContext.save()
                }
                
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func testSettings() {
        guard let voiceId = selectedVoiceId, let modelId = selectedModelId else { return }
        
        Task {
            do {
                let audioData = try await appState.generateSpeech(
                    text: "This is a test of the voice settings.",
                    voiceId: voiceId,
                    modelId: modelId,
                    voiceSettings: voiceSettings
                )
                var duration: TimeInterval = 0
                if let player = try? AVAudioPlayer(data: audioData) {
                    duration = player.duration
                }
                let take = GeneratedTake(
                    audioData: audioData,
                    duration: duration,
                    voiceName: "Test",
                    modelName: "",
                    label: "Test"
                )
                takes = [take]
                selectedTakeIndex = 0
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func addToWorkstation(_ take: GeneratedTake) {
        NotificationCenter.default.post(
            name: .addToWorkstation,
            object: nil,
            userInfo: [
                "audioData": take.audioData,
                "name": String(text.prefix(40)),
                "sourceText": text,
                "voiceName": take.voiceName,
                "modelName": take.modelName,
                "duration": take.duration
            ]
        )
    }
    
    private func clearAll() {
        text = ""
        takes = []
        selectedTakeIndex = nil
    }
    
    private func insertBreakTag() {
        let formatted = String(format: "%.1f", breakDuration)
        text += "<break time=\"\(formatted)s\" />"
    }
}

// MARK: - Generated Take

struct GeneratedTake: Identifiable {
    let id = UUID()
    let audioData: Data
    let duration: TimeInterval
    let voiceName: String
    let modelName: String
    let label: String
}

// MARK: - Take View

struct TakeView: View {
    
    let take: GeneratedTake
    let label: String?
    let isSelected: Bool
    var onSelect: () -> Void
    var onAddToWorkstation: () -> Void
    var onSave: () -> Void
    
    @State private var audioService = AudioService()
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                if let label {
                    Text(label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            isSelected ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08),
                            in: Capsule()
                        )
                }
                
                Text(AudioService.formatTime(take.duration))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    Button(action: onAddToWorkstation) {
                        Label("Add to Workstation", systemImage: "waveform.path.badge.plus")
                            .font(.caption)
                    }
                    .controlSize(.small)
                    .buttonStyle(.bordered)
                    .help("Add this take to the Workstation timeline")
                    
                    Button(action: onSave) {
                        Label("Save", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .controlSize(.small)
                    .help("Export this take to a file")
                }
            }
            
            // Audio player
            AudioPlayerView(audioService: audioService)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.04) : .clear)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .onTapGesture(perform: onSelect)
        .onAppear {
            // Auto-play the first take
            try? audioService.play(data: take.audioData)
        }
    }
}

// MARK: - Selector Card

struct SelectorCard<Content: View>: View {
    let title: String
    let icon: String
    var isLoading: Bool = false
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.03), radius: 3, y: 1)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.quaternary, lineWidth: 0.5)
        )
    }
}

// MARK: - Audio Document

import UniformTypeIdentifiers

struct AudioDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.audio, .mp3, .wav] }
    
    let data: Data
    
    init(data: Data) {
        self.data = data
    }
    
    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
