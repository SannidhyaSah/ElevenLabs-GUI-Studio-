import SwiftUI

// MARK: - Content View

struct ContentView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        @Bindable var state = appState
        
        NavigationSplitView {
            // Sidebar
            VStack(spacing: 0) {
                // Brand header
                HStack(spacing: 10) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("ElevenLabs")
                            .font(.headline)
                        Text("Studio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                
                Divider()
                    .padding(.horizontal, 12)
                
                // Navigation items
                List(SidebarTab.allCases, selection: $state.selectedTab) { tab in
                    Label {
                        Text(tab.rawValue)
                    } icon: {
                        Image(systemName: tab.icon)
                            .foregroundStyle(appState.selectedTab == tab ? Color.accentColor : .secondary)
                    }
                    .tag(tab)
                }
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    // API status
                    HStack(spacing: 8) {
                        Circle()
                            .fill(appState.isAPIKeyValid ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                            .shadow(color: appState.isAPIKeyValid ? .green.opacity(0.5) : .clear, radius: 4)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(appState.isAPIKeyValid ? "Connected" : "No API Key")
                                .font(.caption2.weight(.medium))
                            
                            if let name = appState.currentAPIKeyName, appState.isAPIKeyValid {
                                Text(name)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        // Quick link to docs
                        Link(destination: URL(string: "https://elevenlabs.io/docs")!) {
                            Image(systemName: "book")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .help("ElevenLabs Documentation")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        } detail: {
            // Detail view
            Group {
                switch appState.selectedTab {
                case .playground:
                    PlaygroundView()
                case .voices:
                    VoiceManagementView()
                case .history:
                    HistoryView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(appState.selectedTab.rawValue)
        .alert("Error", isPresented: $state.showError) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage ?? "An unknown error occurred.")
        }
        .onAppear {
            if !appState.isAPIKeyValid {
                appState.selectedTab = .settings
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
