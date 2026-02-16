import SwiftUI

// MARK: - Audio Player View

struct AudioPlayerView: View {
    
    @Bindable var audioService: AudioService
    var onSave: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 14) {
            // Waveform visualization
            WaveformView(
                samples: audioService.waveformSamples,
                progress: audioService.progress,
                onSeek: { percent in
                    audioService.seek(toPercent: percent)
                }
            )
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Controls
            HStack(spacing: 14) {
                // Play/Pause button
                Button(action: {
                    audioService.togglePlayPause()
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .help(audioService.isPlaying ? "Pause" : "Play")
                
                // Time display
                HStack(spacing: 4) {
                    Text(AudioService.formatTime(audioService.currentTime))
                        .font(.system(.caption, design: .monospaced).weight(.medium))
                    
                    Text("/")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                    
                    Text(AudioService.formatTime(audioService.duration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Volume
                HStack(spacing: 6) {
                    Button(action: {
                        audioService.volume = audioService.volume > 0 ? 0 : 1.0
                    }) {
                        Image(systemName: volumeIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                    
                    Slider(value: Binding(
                        get: { Double(audioService.volume) },
                        set: { audioService.volume = Float($0) }
                    ), in: 0...1)
                    .frame(width: 70)
                    .tint(Color.accentColor)
                }
                
                // Save button
                if let onSave {
                    Divider()
                        .frame(height: 20)
                    
                    Button(action: onSave) {
                        Label("Export", systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Export audio file")
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
        }
    }
    
    private var volumeIcon: String {
        if audioService.volume == 0 { return "speaker.slash.fill" }
        if audioService.volume < 0.5 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    
    let samples: [Float]
    let progress: Double
    var onSeek: ((Double) -> Void)?
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let barWidth = max(2, size.width / CGFloat(max(samples.count, 1)) - 1.5)
                let barSpacing = size.width / CGFloat(max(samples.count, 1))
                let midY = size.height / 2
                
                for (index, sample) in samples.enumerated() {
                    let x = CGFloat(index) * barSpacing
                    let barHeight = max(3, CGFloat(sample) * size.height * 0.85)
                    
                    let rect = CGRect(
                        x: x,
                        y: midY - barHeight / 2,
                        width: barWidth,
                        height: barHeight
                    )
                    
                    let normalizedProgress = progress * size.width
                    let isPast = x < normalizedProgress
                    
                    let color: Color = isPast ? Color.accentColor : .primary.opacity(0.15)
                    
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: barWidth / 2),
                        with: .color(color)
                    )
                }
                
                // Playhead line
                let playheadX = progress * size.width
                if playheadX > 0 && playheadX < size.width {
                    let playhead = Path { p in
                        p.move(to: CGPoint(x: playheadX, y: 0))
                        p.addLine(to: CGPoint(x: playheadX, y: size.height))
                    }
                    context.stroke(playhead, with: .color(Color.accentColor.opacity(0.6)), lineWidth: 1.5)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let percent = max(0, min(1, value.location.x / geometry.size.width))
                        onSeek?(percent)
                    }
            )
        }
    }
}
