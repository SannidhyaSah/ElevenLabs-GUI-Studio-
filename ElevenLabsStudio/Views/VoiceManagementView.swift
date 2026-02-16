import SwiftUI

// MARK: - Voice Management View

struct VoiceManagementView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var selectedVoiceTab: VoiceTab = .myVoices
    
    enum VoiceTab: String, CaseIterable {
        case myVoices = "My Voices"
        case cloneVoice = "Clone Voice"
        case voiceLibrary = "Voice Library"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("", selection: $selectedVoiceTab) {
                ForEach(VoiceTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // Tab content
            switch selectedVoiceTab {
            case .myVoices:
                MyVoicesTab()
            case .cloneVoice:
                CloneVoiceTab()
            case .voiceLibrary:
                VoiceLibraryTab()
            }
        }
    }
}

// MARK: - My Voices Tab

struct MyVoicesTab: View {
    
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    
    private var filteredVoices: [Voice] {
        if searchText.isEmpty {
            return appState.voices
        }
        return appState.voices.filter { voice in
            voice.name.localizedCaseInsensitiveContains(searchText) ||
            (voice.description?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (voice.category?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search voices...", text: $searchText)
                    .textFieldStyle(.plain)
                
                Button(action: {
                    Task { await appState.loadVoices() }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(appState.isLoadingVoices)
            }
            .padding(8)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            if appState.isLoadingVoices {
                ProgressView("Loading voices...")
                    .frame(maxHeight: .infinity)
            } else if filteredVoices.isEmpty {
                ContentUnavailableView {
                    Label(
                        searchText.isEmpty ? "No Voices" : "No Results",
                        systemImage: "mic.slash"
                    )
                } description: {
                    Text(searchText.isEmpty
                         ? "Connect an API key to load your voices."
                         : "No voices match your search.")
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredVoices) { voice in
                            VoiceCard(voice: voice) {
                                appState.selectedTab = .playground
                                // Voice will be selected via notification or direct state update
                            }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - Clone Voice Tab

struct CloneVoiceTab: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var voiceName = ""
    @State private var voiceDescription = ""
    @State private var labels = ""
    @State private var removeBackgroundNoise = false
    @State private var selectedFiles: [URL] = []
    @State private var isCloning = false
    @State private var showFileImporter = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Create Voice Clone")
                    .font(.headline)
                
                Text("Upload audio samples to create a custom voice clone. For best results, use clear recordings with minimal background noise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // Voice name
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice Name")
                        .font(.caption.weight(.medium))
                    TextField("Enter a name for your voice clone", text: $voiceName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Description
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description (optional)")
                        .font(.caption.weight(.medium))
                    TextField("Describe the voice characteristics", text: $voiceDescription)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Audio files
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio Samples")
                        .font(.caption.weight(.medium))
                    
                    // Drop zone
                    Button(action: { showFileImporter = true }) {
                        VStack(spacing: 8) {
                            Image(systemName: "waveform.badge.plus")
                                .font(.title)
                                .foregroundStyle(.secondary)
                            Text("Click to browse audio files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("MP3, WAV, M4A supported")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 100)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    // Selected files list
                    ForEach(selectedFiles, id: \.self) { url in
                        HStack {
                            Image(systemName: "waveform")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(url.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Button(action: {
                                selectedFiles.removeAll(where: { $0 == url })
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // Labels
                VStack(alignment: .leading, spacing: 4) {
                    Text("Labels (optional)")
                        .font(.caption.weight(.medium))
                    TextField("e.g., accent:british, age:middle, gender:female", text: $labels)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Remove background noise
                Toggle("Remove background noise", isOn: $removeBackgroundNoise)
                    .font(.caption)
                
                // Create button
                Button(action: createClone) {
                    HStack {
                        if isCloning {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(isCloning ? "Creating voice clone..." : "Create Voice Clone")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(voiceName.isEmpty || selectedFiles.isEmpty || isCloning || !appState.isAPIKeyValid)
            }
            .padding()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.audio, .mp3, .wav, .aiff],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        if !selectedFiles.contains(url) {
                            selectedFiles.append(url)
                        }
                    }
                }
            case .failure(let error):
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func createClone() {
        guard !voiceName.isEmpty, !selectedFiles.isEmpty else { return }
        
        isCloning = true
        
        Task {
            do {
                // Read audio file data
                var audioFiles: [(filename: String, data: Data)] = []
                for url in selectedFiles {
                    let data = try Data(contentsOf: url)
                    audioFiles.append((filename: url.lastPathComponent, data: data))
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Parse labels
                var labelsDict: [String: String]?
                if !labels.isEmpty {
                    labelsDict = [:]
                    for pair in labels.split(separator: ",") {
                        let parts = pair.split(separator: ":", maxSplits: 1)
                        if parts.count == 2 {
                            labelsDict?[String(parts[0]).trimmingCharacters(in: .whitespaces)] =
                                String(parts[1]).trimmingCharacters(in: .whitespaces)
                        }
                    }
                }
                
                let _ = try await appState.api.cloneVoice(
                    name: voiceName,
                    description: voiceDescription.isEmpty ? nil : voiceDescription,
                    labels: labelsDict,
                    audioFiles: audioFiles,
                    removeBackgroundNoise: removeBackgroundNoise
                )
                
                // Success — clear form and refresh
                await MainActor.run {
                    voiceName = ""
                    voiceDescription = ""
                    labels = ""
                    selectedFiles = []
                    removeBackgroundNoise = false
                    isCloning = false
                }
                
                await appState.loadVoices()
                
            } catch {
                await MainActor.run {
                    isCloning = false
                    appState.errorMessage = error.localizedDescription
                    appState.showError = true
                }
            }
        }
    }
}

// MARK: - Voice Library Tab

struct VoiceLibraryTab: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var sharedVoices: [SharedVoice] = []
    @State private var searchText = ""
    @State private var selectedCategory = ""
    @State private var isLoading = false
    @State private var currentPage = 0
    
    private let categories = ["", "professional", "famous", "high_quality"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Filters
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search shared voices...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { loadLibrary() }
                
                Picker("Category", selection: $selectedCategory) {
                    Text("All Categories").tag("")
                    Text("Professional").tag("professional")
                    Text("Famous").tag("famous")
                    Text("High Quality").tag("high_quality")
                }
                .frame(maxWidth: 160)
                .onChange(of: selectedCategory) { _, _ in loadLibrary() }
            }
            .padding(8)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            .padding(.bottom, 8)
            
            if isLoading {
                ProgressView("Loading voice library...")
                    .frame(maxHeight: .infinity)
            } else if sharedVoices.isEmpty {
                ContentUnavailableView {
                    Label("Voice Library", systemImage: "person.2.wave.2")
                } description: {
                    Text("Search the ElevenLabs shared voice library to find voices.")
                } actions: {
                    Button("Load Library") {
                        loadLibrary()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sharedVoices) { voice in
                            SharedVoiceCard(voice: voice) {
                                // Voice library voices can be used directly by voice_id
                            }
                        }
                        
                        // Load more
                        Button("Load More") {
                            currentPage += 1
                            loadLibrary(append: true)
                        }
                        .padding()
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            if sharedVoices.isEmpty {
                loadLibrary()
            }
        }
    }
    
    private func loadLibrary(append: Bool = false) {
        guard appState.isAPIKeyValid else { return }
        
        if !append {
            currentPage = 0
        }
        
        isLoading = !append
        
        Task {
            do {
                let response = try await appState.api.fetchSharedVoices(
                    pageSize: 30,
                    page: currentPage,
                    search: searchText.isEmpty ? nil : searchText,
                    category: selectedCategory.isEmpty ? nil : selectedCategory
                )
                
                await MainActor.run {
                    if append {
                        sharedVoices.append(contentsOf: response.voices)
                    } else {
                        sharedVoices = response.voices
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    appState.errorMessage = error.localizedDescription
                    appState.showError = true
                }
            }
        }
    }
}
