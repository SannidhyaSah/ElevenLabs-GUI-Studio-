import Foundation
import AVFoundation
import Combine

// MARK: - Audio Service

/// Manages audio playback using AVFoundation.
@Observable
final class AudioService: NSObject {
    
    // MARK: - State
    
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var volume: Float = 1.0 {
        didSet { player?.volume = volume }
    }
    
    /// Waveform samples for visualization (normalized 0-1).
    var waveformSamples: [Float] = []
    
    // MARK: - Private
    
    private var player: AVAudioPlayer?
    private var timer: Timer?
    
    // MARK: - Playback
    
    /// Load and play audio from raw data.
    func play(data: Data) throws {
        stop()
        
        player = try AVAudioPlayer(data: data)
        player?.delegate = self
        player?.volume = volume
        player?.prepareToPlay()
        
        duration = player?.duration ?? 0
        
        // Extract waveform
        extractWaveform(from: data)
        
        player?.play()
        isPlaying = true
        startTimer()
    }
    
    /// Load and play audio from a file URL.
    func play(url: URL) throws {
        stop()
        
        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.volume = volume
        player?.prepareToPlay()
        
        duration = player?.duration ?? 0
        
        // Extract waveform from file
        if let data = try? Data(contentsOf: url) {
            extractWaveform(from: data)
        }
        
        player?.play()
        isPlaying = true
        startTimer()
    }
    
    /// Toggle play/pause.
    func togglePlayPause() {
        guard let player else { return }
        
        if player.isPlaying {
            player.pause()
            isPlaying = false
            stopTimer()
        } else {
            player.play()
            isPlaying = true
            startTimer()
        }
    }
    
    /// Pause playback.
    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }
    
    /// Stop playback and reset.
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        stopTimer()
    }
    
    /// Seek to a specific time.
    func seek(to time: TimeInterval) {
        player?.currentTime = max(0, min(time, duration))
        currentTime = player?.currentTime ?? 0
    }
    
    /// Seek to a percentage (0.0 - 1.0).
    func seek(toPercent percent: Double) {
        let targetTime = percent * duration
        seek(to: targetTime)
    }
    
    /// Progress as a percentage (0.0 - 1.0).
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.currentTime = self.player?.currentTime ?? 0
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Waveform Extraction
    
    private func extractWaveform(from data: Data, sampleCount: Int = 100) {
        // Simple waveform extraction by sampling the audio data amplitude
        guard data.count > sampleCount * 2 else {
            waveformSamples = Array(repeating: 0.5, count: sampleCount)
            return
        }
        
        let bytesPerSample = data.count / sampleCount
        var samples: [Float] = []
        
        data.withUnsafeBytes { buffer in
            let bytes = buffer.bindMemory(to: UInt8.self)
            
            for i in 0..<sampleCount {
                let offset = i * bytesPerSample
                let endOffset = min(offset + bytesPerSample, data.count)
                
                // Calculate RMS of the chunk
                var sum: Float = 0
                var count: Float = 0
                
                for j in stride(from: offset, to: endOffset, by: 2) {
                    if j + 1 < data.count {
                        let value = Float(Int16(bytes[j]) | (Int16(bytes[j + 1]) << 8))
                        sum += abs(value) / 32768.0
                        count += 1
                    }
                }
                
                let rms = count > 0 ? sum / count : 0
                samples.append(min(1.0, rms * 3.0)) // Amplify for visibility
            }
        }
        
        waveformSamples = samples.isEmpty ? Array(repeating: 0.3, count: sampleCount) : samples
    }
    
    // MARK: - Time Formatting
    
    /// Format a time interval as MM:SS.
    static func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite else { return "0:00" }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Export
    
    /// Save audio data to a file.
    static func saveAudioToFile(data: Data, format: OutputFormat, to url: URL) throws {
        try data.write(to: url)
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        isPlaying = false
        stopTimer()
    }
}
