import SwiftUI
import SwiftData
import AVFoundation

// MARK: - History View

struct HistoryView: View {
    
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \GenerationHistory.date, order: .reverse)
    private var historyItems: [GenerationHistory]
    
    @State private var searchText = ""
    @State private var audioService = AudioService()
    @State private var playingItemId: UUID?
    @State private var showClearConfirmation = false
    
    private var filteredItems: [GenerationHistory] {
        if searchText.isEmpty {
            return historyItems
        }
        return historyItems.filter { item in
            item.text.localizedCaseInsensitiveContains(searchText) ||
            item.voiceName.localizedCaseInsensitiveContains(searchText) ||
            item.modelName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Generation History")
                    .font(.headline)
                
                Spacer()
                
                Text("\(historyItems.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Button("Clear All") {
                    showClearConfirmation = true
                }
                .disabled(historyItems.isEmpty)
            }
            .padding()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search history...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            
            Divider()
                .padding(.top, 8)
            
            // History list
            if filteredItems.isEmpty {
                ContentUnavailableView {
                    Label(
                        searchText.isEmpty ? "No History" : "No Results",
                        systemImage: searchText.isEmpty ? "clock" : "magnifyingglass"
                    )
                } description: {
                    Text(searchText.isEmpty
                         ? "Your speech generations will appear here."
                         : "No history items match your search.")
                }
                .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredItems) { item in
                        HistoryItemRow(
                            item: item,
                            isPlaying: playingItemId == item.id,
                            onPlay: { playItem(item) },
                            onUseText: { useText(item) },
                            onAddToWorkstation: { addItemToWorkstation(item) },
                            onDelete: { deleteItem(item) }
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            "Clear all history?",
            isPresented: $showClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                clearAllHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. All generation history and saved audio will be permanently deleted.")
        }
    }
    
    // MARK: - Actions
    
    private func playItem(_ item: GenerationHistory) {
        guard let audioData = item.audioData else { return }
        
        do {
            try audioService.play(data: audioData)
            playingItemId = item.id
        } catch {
            appState.errorMessage = "Failed to play audio: \(error.localizedDescription)"
            appState.showError = true
        }
    }
    
    private func useText(_ item: GenerationHistory) {
        // Switch to playground and populate
        appState.selectedTab = .playground
        
        // Post notification with history item data
        NotificationCenter.default.post(
            name: .loadFromHistory,
            object: nil,
            userInfo: [
                "text": item.text,
                "voiceId": item.voiceId,
                "modelId": item.modelId
            ]
        )
    }
    
    private func deleteItem(_ item: GenerationHistory) {
        if playingItemId == item.id {
            audioService.stop()
            playingItemId = nil
        }
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    private func addItemToWorkstation(_ item: GenerationHistory) {
        guard let audioData = item.audioData else { return }
        appState.addToWorkstation(
            audioData: audioData,
            name: String(item.text.prefix(40)),
            sourceText: item.text,
            voiceName: item.voiceName,
            modelName: item.modelName,
            duration: item.audioData.flatMap { try? AVAudioPlayer(data: $0) }?.duration ?? 0
        )
    }
    
    private func clearAllHistory() {
        audioService.stop()
        playingItemId = nil
        
        for item in historyItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    
    let item: GenerationHistory
    let isPlaying: Bool
    var onPlay: () -> Void
    var onUseText: () -> Void
    var onAddToWorkstation: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(item.voiceName)
                    .font(.subheadline.weight(.medium))
                
                Text("•")
                    .foregroundStyle(.tertiary)
                
                Text(item.modelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text(item.formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            // Text preview
            Text(item.textPreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            
            // Settings badges
            HStack(spacing: 6) {
                SettingsBadge(label: "Stab", value: String(format: "%.1f", item.stability))
                SettingsBadge(label: "Sim", value: String(format: "%.1f", item.similarityBoost))
                if item.style > 0 {
                    SettingsBadge(label: "Style", value: String(format: "%.1f", item.style))
                }
                if item.speed != 1.0 {
                    SettingsBadge(label: "Speed", value: String(format: "%.1fx", item.speed))
                }
            }
            
            // Actions
            HStack {
                // Audio status
                HStack(spacing: 4) {
                    Image(systemName: item.hasAudio ? "waveform" : "exclamationmark.triangle")
                        .font(.caption2)
                    Text(item.hasAudio ? "Audio available" : "No audio")
                        .font(.caption2)
                }
                .foregroundStyle(item.hasAudio ? .green : .orange)
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 8) {
                    if item.hasAudio {
                        Button(action: onPlay) {
                            Label(isPlaying ? "Playing..." : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        }
                        .controlSize(.small)
                    }
                    
                    if item.hasAudio {
                        Button(action: onAddToWorkstation) {
                            Label("Workstation", systemImage: "waveform.path.badge.plus")
                        }
                        .controlSize(.small)
                    }
                    
                    Button(action: onUseText) {
                        Label("Use Text", systemImage: "text.insert")
                    }
                    .controlSize(.small)
                    
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Settings Badge

struct SettingsBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Notification

extension Notification.Name {
    static let loadFromHistory = Notification.Name("loadFromHistory")
}
