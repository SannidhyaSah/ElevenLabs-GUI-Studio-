import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var newAPIKey = ""
    @State private var newKeyName = ""
    @State private var selectedKeyName: String?
    @State private var isSaving = false
    @State private var saveError: String?
    @State private var showKeyField = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // MARK: - API Key Management
                
                VStack(alignment: .leading, spacing: 16) {
                    // Section header
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("API Key Management")
                            .font(.title3.weight(.semibold))
                    }
                    
                    Text("Your API keys are stored securely in the macOS Keychain.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Status card
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(appState.isAPIKeyValid ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            Image(systemName: appState.isAPIKeyValid ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(appState.isAPIKeyValid ? .green : .orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.isAPIKeyValid ? "Connected" : "Not Connected")
                                .font(.subheadline.weight(.semibold))
                            
                            Text(appState.isAPIKeyValid
                                 ? "API key \"\(appState.currentAPIKeyName ?? "")\" is active and validated."
                                 : "Add an ElevenLabs API key to get started.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(appState.isAPIKeyValid ? Color.green.opacity(0.05) : Color.orange.opacity(0.05))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(appState.isAPIKeyValid ? Color.green.opacity(0.2) : Color.orange.opacity(0.2), lineWidth: 1)
                    )
                    
                    // Saved keys list
                    if !appState.savedAPIKeyNames.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Saved Keys")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            ForEach(appState.savedAPIKeyNames, id: \.self) { name in
                                HStack(spacing: 12) {
                                    Image(systemName: appState.currentAPIKeyName == name ? "key.fill" : "key")
                                        .foregroundStyle(appState.currentAPIKeyName == name ? Color.accentColor : .secondary)
                                        .frame(width: 20)
                                    
                                    Text(name)
                                        .font(.body)
                                    
                                    if appState.currentAPIKeyName == name {
                                        Text("Active")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.accentColor, in: Capsule())
                                    }
                                    
                                    Spacer()
                                    
                                    if appState.currentAPIKeyName != name {
                                        Button("Activate") {
                                            switchToKey(name)
                                        }
                                        .controlSize(.small)
                                        .buttonStyle(.bordered)
                                    }
                                    
                                    Button(action: { deleteKey(name) }) {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundStyle(.red.opacity(0.8))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete this API key")
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(appState.currentAPIKeyName == name ? Color.accentColor.opacity(0.05) : .clear)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Add new key
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Add New Key")
                                .font(.subheadline.weight(.medium))
                            
                            Spacer()
                            
                            Link(destination: URL(string: "https://elevenlabs.io/app/settings/api-keys")!) {
                                Label("Get API Key", systemImage: "arrow.up.right.square")
                                    .font(.caption)
                            }
                        }
                        
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 6) {
                                TextField("Key name (e.g., Personal, Work)", text: $newKeyName)
                                    .textFieldStyle(.roundedBorder)
                                
                                SecureField("Paste your ElevenLabs API key", text: $newAPIKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button(action: saveAPIKey) {
                                Group {
                                    if isSaving {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                    }
                                }
                                .frame(width: 32, height: 32)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                            .disabled(newAPIKey.isEmpty || newKeyName.isEmpty || isSaving)
                            .help("Save and validate API key")
                        }
                        
                        if let error = saveError {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
                
                // MARK: - About
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(Color.accentColor)
                        Text("About")
                            .font(.title3.weight(.semibold))
                    }
                    
                    VStack(spacing: 12) {
                        InfoRow(label: "Version", value: "4.0.0")
                        InfoRow(label: "Platform", value: "Native macOS (SwiftUI)")
                        
                        Divider()
                        
                        HStack {
                            Text("Created by")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Link("@SannidhyaSah", destination: URL(string: "https://github.com/SannidhyaSah")!)
                                .font(.caption.weight(.medium))
                        }
                        
                        HStack {
                            Text("Source Code")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Link("GitHub", destination: URL(string: "https://github.com/SannidhyaSah/ElevenLabs-GUI-Studio-")!)
                                .font(.caption.weight(.medium))
                        }
                        
                        HStack {
                            Text("ElevenLabs API")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Link("Documentation", destination: URL(string: "https://elevenlabs.io/docs")!)
                                .font(.caption.weight(.medium))
                        }
                        
                        Divider()
                        
                        Text("This is an unofficial application and is not affiliated with ElevenLabs. You must have a valid ElevenLabs API key to use this application.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(20)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
            }
            .padding(24)
            .frame(maxWidth: 580)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Actions
    
    private func saveAPIKey() {
        guard !newAPIKey.isEmpty, !newKeyName.isEmpty else { return }
        
        isSaving = true
        saveError = nil
        
        Task {
            do {
                try await appState.saveAPIKey(name: newKeyName, key: newAPIKey)
                
                await MainActor.run {
                    newAPIKey = ""
                    newKeyName = ""
                    isSaving = false
                }
            } catch {
                await MainActor.run {
                    saveError = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
    
    private func switchToKey(_ name: String) {
        Task {
            do {
                try await appState.switchAPIKey(name: name)
            } catch {
                appState.errorMessage = error.localizedDescription
                appState.showError = true
            }
        }
    }
    
    private func deleteKey(_ name: String) {
        do {
            try appState.deleteAPIKey(name: name)
        } catch {
            appState.errorMessage = error.localizedDescription
            appState.showError = true
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
        }
    }
}
