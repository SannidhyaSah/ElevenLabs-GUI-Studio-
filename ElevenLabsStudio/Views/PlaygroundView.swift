import SwiftUI
import SwiftData

// MARK: - Playground View

struct PlaygroundView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @State private var text = ""
    @State private var selectedVoiceId: String?
    @State private var selectedModelId: String?
    @State private var voiceSettings = VoiceSettings.balanced
    @State private var selectedOutputFormat: OutputFormat = .mp3_44100_128
    @State private var audioService = AudioService()
    @State private var hasGeneratedAudio = false
    @State private var lastAudioData: Data?
    @State private var showExportDialog = false
    @State private var showParametersPanel = true
    @State private var breakDuration: Double = 1.0
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Voice & Model selectors
                    HStack(spacing: 12) {
                        // Voice picker
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
                                
                                Button(action: {
                                    Task { await appState.loadVoices() }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .disabled(appState.isLoadingVoices)
                            }
                        }
                        
                        // Model picker
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
                                
                                Button(action: {
                                    Task { await appState.loadModels() }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.secondary)
                                .disabled(appState.isLoadingModels)
                            }
                        }
                        
                        // Format picker
                        SelectorCard(title: "Format", icon: "waveform") {
                            Picker("", selection: $selectedOutputFormat) {
                                ForEach(OutputFormat.allCases) { format in
                                    Text(format.displayName).tag(format)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    
                    // Text input area
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Text", systemImage: "text.alignleft")
                                .font(.subheadline.weight(.semibold))
                            
                            Spacer()
                            
                            // Character count
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
                            .frame(minHeight: 140, maxHeight: 300)
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
                        Button(action: {
                            text = ""
                            hasGeneratedAudio = false
                            audioService.stop()
                            lastAudioData = nil
                        }) {
                            Label("New", systemImage: "doc")
                        }
                        .controlSize(.regular)
                        .keyboardShortcut("n", modifiers: .command)
                        
                        Spacer()
                        
                        if !appState.isAPIKeyValid {
                            Label("Add API key in Settings", systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        Button(action: generateSpeech) {
                            HStack(spacing: 8) {
                                if appState.isGenerating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "waveform.badge.plus")
                                }
                                Text(appState.isGenerating ? "Generating..." : "Generate Speech")
                                    .fontWeight(.medium)
                            }
                            .frame(minWidth: 160)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.accentColor)
                        .controlSize(.large)
                        .disabled(text.isEmpty || selectedVoiceId == nil || selectedModelId == nil || appState.isGenerating || !appState.isAPIKeyValid)
                        .keyboardShortcut(.return, modifiers: .command)
                    }
                    
                    // Audio player
                    if hasGeneratedAudio {
                        AudioPlayerView(
                            audioService: audioService,
                            onSave: { showExportDialog = true }
                        )
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
                
                // Panel toggle
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
        .animation(.spring(duration: 0.3), value: hasGeneratedAudio)
        .fileExporter(
            isPresented: $showExportDialog,
            document: AudioDocument(data: lastAudioData ?? Data()),
            contentType: .audio,
            defaultFilename: "elevenlabs-output.\(selectedOutputFormat.fileExtension)"
        ) { result in
            if case .failure(let error) = result {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
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
        .onReceive(NotificationCenter.default.publisher(for: .newGeneration)) { _ in
            text = ""
            hasGeneratedAudio = false
            audioService.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: .generateSpeech)) { _ in
            generateSpeech()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveAudio)) { _ in
            if hasGeneratedAudio { showExportDialog = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .loadFromHistory)) { notification in
            if let userInfo = notification.userInfo {
                if let historyText = userInfo["text"] as? String { text = historyText }
                if let voiceId = userInfo["voiceId"] as? String { selectedVoiceId = voiceId }
                if let modelId = userInfo["modelId"] as? String { selectedModelId = modelId }
            }
        }
    }
    
    // MARK: - Actions
    
    private func generateSpeech() {
        guard !text.isEmpty,
              let voiceId = selectedVoiceId,
              let modelId = selectedModelId else { return }
        
        Task {
            do {
                let audioData = try await appState.generateSpeech(
                    text: text,
                    voiceId: voiceId,
                    modelId: modelId,
                    voiceSettings: voiceSettings,
                    outputFormat: selectedOutputFormat
                )
                
                lastAudioData = audioData
                hasGeneratedAudio = true
                
                try audioService.play(data: audioData)
                
                let voiceName = appState.voices.first(where: { $0.voiceId == voiceId })?.name ?? "Unknown"
                let modelName = appState.models.first(where: { $0.modelId == modelId })?.name ?? "Unknown"
                
                let historyItem = GenerationHistory(
                    text: text,
                    voiceId: voiceId,
                    voiceName: voiceName,
                    modelId: modelId,
                    modelName: modelName,
                    voiceSettings: voiceSettings,
                    outputFormat: selectedOutputFormat,
                    audioData: audioData
                )
                modelContext.insert(historyItem)
                try? modelContext.save()
                
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func testSettings() {
        guard let voiceId = selectedVoiceId,
              let modelId = selectedModelId else { return }
        
        Task {
            do {
                let audioData = try await appState.generateSpeech(
                    text: "This is a test of the voice settings. You should hear changes based on the current parameters.",
                    voiceId: voiceId,
                    modelId: modelId,
                    voiceSettings: voiceSettings
                )
                try audioService.play(data: audioData)
                hasGeneratedAudio = true
                lastAudioData = audioData
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func insertBreakTag() {
        let formatted = String(format: "%.1f", breakDuration)
        text += "<break time=\"\(formatted)s\" />"
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

// MARK: - Audio Document (for file export)

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
