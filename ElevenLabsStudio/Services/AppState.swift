import Foundation
import SwiftUI

// MARK: - App State

/// Global observable state for the application.
@Observable
final class AppState {
    
    // MARK: - API
    
    let api = ElevenLabsAPI()
    
    /// Name of the currently active API key.
    var currentAPIKeyName: String? = KeychainService.currentAPIKeyName
    
    /// Whether an API key is configured and valid.
    var isAPIKeyValid: Bool = false
    
    /// All saved API key names.
    var savedAPIKeyNames: [String] = []
    
    // MARK: - Voices & Models
    
    var voices: [Voice] = []
    var models: [AIModel] = []
    var isLoadingVoices = false
    var isLoadingModels = false
    
    // MARK: - Generation
    
    var isGenerating = false
    var generatedAudioData: Data?
    var currentVoiceSettings = VoiceSettings.balanced
    var selectedOutputFormat: OutputFormat = .mp3_44100_128
    
    // MARK: - Navigation
    
    var selectedTab: SidebarTab = .playground
    
    // MARK: - Errors
    
    var errorMessage: String?
    var showError = false
    
    // MARK: - Initialization
    
    init() {
        loadSavedAPIKeyNames()
        
        Task {
            await initializeAPIKey()
        }
    }
    
    // MARK: - API Key Management
    
    private func loadSavedAPIKeyNames() {
        savedAPIKeyNames = KeychainService.listAPIKeyNames()
    }
    
    private func initializeAPIKey() async {
        guard let name = currentAPIKeyName,
              let key = KeychainService.retrieveAPIKey(name: name) else {
            return
        }
        
        await api.setAPIKey(key)
        
        do {
            isAPIKeyValid = try await api.validateAPIKey()
            if isAPIKeyValid {
                await loadVoices()
                await loadModels()
            }
        } catch {
            isAPIKeyValid = false
        }
    }
    
    /// Save a new API key and set it as active.
    func saveAPIKey(name: String, key: String) async throws {
        // Validate by testing the key
        let testAPI = ElevenLabsAPI()
        await testAPI.setAPIKey(key)
        let _ = try await testAPI.validateAPIKey()
        
        // Save to Keychain
        try KeychainService.saveAPIKey(key, name: name)
        KeychainService.currentAPIKeyName = name
        
        // Update state
        currentAPIKeyName = name
        isAPIKeyValid = true
        loadSavedAPIKeyNames()
        
        // Set as active
        await api.setAPIKey(key)
        
        // Load data
        await loadVoices()
        await loadModels()
    }
    
    /// Switch to a different saved API key.
    func switchAPIKey(name: String) async throws {
        guard let key = KeychainService.retrieveAPIKey(name: name) else {
            throw KeychainError.saveFailed(-1)
        }
        
        await api.setAPIKey(key)
        
        let valid = try await api.validateAPIKey()
        
        if valid {
            KeychainService.currentAPIKeyName = name
            currentAPIKeyName = name
            isAPIKeyValid = true
            
            await loadVoices()
            await loadModels()
        }
    }
    
    /// Delete a saved API key.
    func deleteAPIKey(name: String) throws {
        try KeychainService.deleteAPIKey(name: name)
        loadSavedAPIKeyNames()
        
        // If we deleted the active key, clear state
        if currentAPIKeyName == name {
            currentAPIKeyName = nil
            KeychainService.currentAPIKeyName = nil
            isAPIKeyValid = false
            voices = []
            models = []
            
            Task {
                await api.setAPIKey(nil)
            }
        }
    }
    
    // MARK: - Data Loading
    
    /// Load voices from the API.
    @MainActor
    func loadVoices() async {
        guard isAPIKeyValid else { return }
        isLoadingVoices = true
        
        do {
            let response = try await api.fetchVoices(pageSize: 100)
            voices = response.voices
        } catch {
            handleError(error)
        }
        
        isLoadingVoices = false
    }
    
    /// Load models from the API.
    @MainActor
    func loadModels() async {
        guard isAPIKeyValid else { return }
        isLoadingModels = true
        
        do {
            models = try await api.fetchModels()
        } catch {
            handleError(error)
        }
        
        isLoadingModels = false
    }
    
    /// Generate speech from text.
    @MainActor
    func generateSpeech(
        text: String,
        voiceId: String,
        modelId: String,
        voiceSettings: VoiceSettings? = nil,
        outputFormat: OutputFormat = .mp3_44100_128
    ) async throws -> Data {
        guard isAPIKeyValid else {
            throw APIError.noAPIKey
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        let settings = voiceSettings ?? currentVoiceSettings
        
        let audioData = try await api.generateSpeech(
            text: text,
            voiceId: voiceId,
            modelId: modelId,
            voiceSettings: settings,
            outputFormat: outputFormat
        )
        
        generatedAudioData = audioData
        return audioData
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
}

// MARK: - Sidebar Tab

enum SidebarTab: String, CaseIterable, Identifiable {
    case playground = "Playground"
    case workstation = "Workstation"
    case voices = "Voices"
    case history = "History"
    case settings = "Settings"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .playground: return "slider.horizontal.3"
        case .workstation: return "waveform.path"
        case .voices: return "mic.fill"
        case .history: return "clock.fill"
        case .settings: return "gearshape.fill"
        }
    }
}
