import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct ElevenLabsStudioApp: App {
    
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .modelContainer(for: [
            GenerationHistory.self,
            VoicePreset.self
        ])
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 750)
        .commands {
            // Custom menu commands
            CommandGroup(replacing: .newItem) {
                Button("New Generation") {
                    NotificationCenter.default.post(name: .newGeneration, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .newItem) {
                Button("Generate Speech") {
                    NotificationCenter.default.post(name: .generateSpeech, object: nil)
                }
                .keyboardShortcut(.return, modifiers: .command)
                
                Divider()
                
                Button("Save Audio") {
                    NotificationCenter.default.post(name: .saveAudio, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }
            
            CommandGroup(replacing: .help) {
                Link("ElevenLabs Documentation",
                     destination: URL(string: "https://elevenlabs.io/docs")!)
                
                Link("API Reference",
                     destination: URL(string: "https://elevenlabs.io/docs/api-reference")!)
                
                Divider()
                
                Link("Report an Issue",
                     destination: URL(string: "https://github.com/SannidhyaSah/ElevenLabs-GUI-Studio-/issues")!)
            }
        }
        
        #if os(macOS)
        Settings {
            SettingsView()
                .environment(appState)
                .modelContainer(for: [VoicePreset.self])
        }
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newGeneration = Notification.Name("newGeneration")
    static let generateSpeech = Notification.Name("generateSpeech")
    static let saveAudio = Notification.Name("saveAudio")
}
