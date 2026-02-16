import SwiftUI

// MARK: - Voice Card

struct VoiceCard: View {
    
    let voice: Voice
    var onUse: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Voice icon
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.headline)
                
                if let description = voice.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if let category = voice.category {
                        CategoryBadge(text: category)
                    }
                    
                    if let voiceType = voice.voiceType {
                        CategoryBadge(text: voiceType, color: .blue)
                    }
                    
                    if let languages = voice.verifiedLanguages, !languages.isEmpty {
                        let langText = languages.compactMap(\.language).prefix(3).joined(separator: ", ")
                        if !langText.isEmpty {
                            CategoryBadge(text: langText, color: .purple)
                        }
                    }
                }
            }
            
            Spacer()
            
            if let onUse {
                Button("Use", action: onUse)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Shared Voice Card

struct SharedVoiceCard: View {
    
    let voice: SharedVoice
    var onAdd: (() -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.wave.2.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.headline)
                
                if let description = voice.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 8) {
                    if let category = voice.category {
                        CategoryBadge(text: category)
                    }
                    
                    if let languages = voice.languages, !languages.isEmpty {
                        let langText = languages.compactMap(\.language).prefix(3).joined(separator: ", ")
                        if !langText.isEmpty {
                            CategoryBadge(text: langText, color: .purple)
                        }
                    }
                }
            }
            
            Spacer()
            
            if let onAdd {
                Button("Add", action: onAdd)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Category Badge

struct CategoryBadge: View {
    let text: String
    var color: Color = .secondary
    
    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1), in: Capsule())
    }
}
