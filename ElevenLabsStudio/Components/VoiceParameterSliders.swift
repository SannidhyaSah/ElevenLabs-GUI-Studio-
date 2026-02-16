import SwiftUI
import SwiftData

// MARK: - Voice Parameter Sliders

struct VoiceParameterSliders: View {
    
    @Binding var settings: VoiceSettings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VoicePreset.createdAt) private var presets: [VoicePreset]
    
    @State private var selectedPresetId: UUID?
    @State private var newPresetName = ""
    @State private var showSavePreset = false
    
    var onTestSettings: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            // Preset controls
            HStack {
                // Preset picker
                Picker("Preset", selection: $selectedPresetId) {
                    Text("Custom").tag(nil as UUID?)
                    ForEach(presets) { preset in
                        Text(preset.name).tag(preset.id as UUID?)
                    }
                }
                .frame(maxWidth: 200)
                .onChange(of: selectedPresetId) { _, newValue in
                    if let id = newValue, let preset = presets.first(where: { $0.id == id }) {
                        settings = preset.voiceSettings
                    }
                }
                
                Spacer()
                
                // Save preset
                Button(action: { showSavePreset.toggle() }) {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save current settings as preset")
                .popover(isPresented: $showSavePreset) {
                    VStack(spacing: 12) {
                        Text("Save Preset")
                            .font(.headline)
                        
                        TextField("Preset name", text: $newPresetName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 200)
                        
                        HStack {
                            Button("Cancel") {
                                showSavePreset = false
                                newPresetName = ""
                            }
                            
                            Button("Save") {
                                savePreset()
                            }
                            .disabled(newPresetName.trimmingCharacters(in: .whitespaces).isEmpty)
                            .keyboardShortcut(.return)
                        }
                    }
                    .padding()
                }
                
                // Delete preset
                if let id = selectedPresetId, let preset = presets.first(where: { $0.id == id }), !preset.isDefault {
                    Button(action: { deletePreset(preset) }) {
                        Image(systemName: "trash")
                    }
                    .help("Delete selected preset")
                }
                
                Divider()
                    .frame(height: 16)
                
                // Test & Reset
                if let onTestSettings {
                    Button("Test", action: onTestSettings)
                        .help("Generate test audio with current settings")
                }
                
                Button("Reset") {
                    settings = .balanced
                    selectedPresetId = nil
                }
                .help("Reset to default settings")
            }
            
            // Sliders grid
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 12) {
                // Stability
                parameterRow(
                    label: "Stability",
                    value: $settings.stability,
                    range: 0...1,
                    helpText: "Lower = more emotional, Higher = more consistent"
                )
                
                // Similarity Boost
                parameterRow(
                    label: "Similarity",
                    value: $settings.similarityBoost,
                    range: 0...1,
                    helpText: "How closely the AI adheres to the original voice"
                )
                
                // Style
                parameterRow(
                    label: "Style",
                    value: $settings.style,
                    range: 0...1,
                    helpText: "Style exaggeration (higher = more distinctive, increases latency)"
                )
                
                // Speed
                parameterRow(
                    label: "Speed",
                    value: $settings.speed,
                    range: 0.5...2.0,
                    helpText: "Speech speed (0.5x to 2.0x)"
                )
                
                // Speaker Boost
                GridRow {
                    Text("Speaker Boost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .gridColumnAlignment(.trailing)
                    
                    Toggle("", isOn: $settings.useSpeakerBoost)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .help("Boosts similarity to original speaker (increases latency)")
                }
            }
        }
        .onAppear {
            ensureDefaultPresets()
        }
    }
    
    // MARK: - Parameter Row
    
    @ViewBuilder
    private func parameterRow(
        label: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        helpText: String
    ) -> some View {
        GridRow {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            
            HStack(spacing: 8) {
                Slider(value: value, in: range, step: 0.01)
                
                Text(String(format: "%.2f", value.wrappedValue))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
            .help(helpText)
        }
    }
    
    // MARK: - Preset Management
    
    private func savePreset() {
        let name = newPresetName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        // Check for existing preset with same name
        if let existing = presets.first(where: { $0.name == name }) {
            existing.update(from: settings)
        } else {
            let preset = VoicePreset(
                name: name,
                stability: settings.stability,
                similarityBoost: settings.similarityBoost,
                style: settings.style,
                speed: settings.speed,
                useSpeakerBoost: settings.useSpeakerBoost
            )
            modelContext.insert(preset)
        }
        
        try? modelContext.save()
        
        newPresetName = ""
        showSavePreset = false
    }
    
    private func deletePreset(_ preset: VoicePreset) {
        modelContext.delete(preset)
        try? modelContext.save()
        selectedPresetId = nil
    }
    
    private func ensureDefaultPresets() {
        // Create default presets if none exist
        guard presets.isEmpty else { return }
        
        for (name, voiceSettings) in VoicePreset.defaults {
            let preset = VoicePreset(
                name: name,
                stability: voiceSettings.stability,
                similarityBoost: voiceSettings.similarityBoost,
                style: voiceSettings.style,
                speed: voiceSettings.speed,
                useSpeakerBoost: voiceSettings.useSpeakerBoost,
                isDefault: true
            )
            modelContext.insert(preset)
        }
        
        try? modelContext.save()
    }
}
