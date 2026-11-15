// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Keyed SFX + music. Prefers Fire Fox files from `Assets/Generated/` via AssetManifest;
/// falls back to procedural sine blips / drone loop.
public final class JuiceSound: @unchecked Sendable {
    public static let shared = JuiceSound()

    private var engine: AVAudioEngine?
    private var musicPlayer: AVAudioPlayerNode?
    private var ready = false
    private var musicOn = false

    private init() {}

    public func prepare() {
        guard !ready else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        let eng = AVAudioEngine()
        _ = eng.mainMixerNode
        do {
            try eng.start()
            engine = eng
            ready = true
        } catch {
            ready = false
        }
    }

    public func play(_ key: AssetKey) {
        prepare()
        if let url = AssetManifest.shared.url(for: key, ext: "wav")
            ?? AssetManifest.shared.url(for: key, ext: "m4a")
            ?? AssetManifest.shared.url(for: key, ext: "mp3") {
            playFile(url)
            return
        }
        // Procedural placeholders mapped to keys
        let tone: (Double, Double, Float) = {
            switch key {
            case .sfxJump: return (520, 0.07, 0.28)
            case .sfxLand: return (180, 0.05, 0.22)
            case .sfxCollectShiny: return (920, 0.1, 0.24)
            case .sfxPounce: return (360, 0.08, 0.3)
            case .sfxHit: return (160, 0.09, 0.32)
            case .sfxWin: return (660, 0.35, 0.3)
            case .sfxFail: return (110, 0.3, 0.3)
            case .sfxMaskMode: return (440, 0.25, 0.3)
            default: return (300, 0.05, 0.15)
            }
        }()
        guard let engine else { return }
        blip(engine: engine, frequency: tone.0, duration: tone.1, volume: tone.2)
    }

    public func startMusic() {
        prepare()
        guard !musicOn, let engine else { return }
        if let url = AssetManifest.shared.url(for: .musicHeistLoop, ext: "m4a")
            ?? AssetManifest.shared.url(for: .musicHeistLoop, ext: "wav")
            ?? AssetManifest.shared.url(for: .musicHeistLoop, ext: "mp3") {
            playFile(url, loop: true)
            musicOn = true
            return
        }
        // Soft procedural drone loop
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let sampleRate = 22050.0
        let seconds = 4.0
        let frames = AVAudioFrameCount(sampleRate * seconds)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let a = sin(2 * .pi * 110 * t) * 0.04
            let b = sin(2 * .pi * 164.8 * t) * 0.03
            let c = sin(2 * .pi * 220 * t) * 0.02
            let pulse = 0.6 + 0.4 * sin(2 * .pi * 0.5 * t)
            data[i] = Float((a + b + c) * pulse)
        }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        player.play()
        musicPlayer = player
        musicOn = true
    }

    public func stopMusic() {
        musicPlayer?.stop()
        if let musicPlayer, let engine {
            engine.detach(musicPlayer)
        }
        musicPlayer = nil
        musicOn = false
    }

    private func playFile(_ url: URL, loop: Bool = false) {
        guard let engine else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            let opts: AVAudioPlayerNodeBufferOptions = loop ? [.loops] : []
            player.scheduleFile(file, at: nil, completionHandler: nil)
            // scheduleFile doesn't take loops — use buffer for loop
            if loop {
                let frameCount = AVAudioFrameCount(file.length)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount) else { return }
                try file.read(into: buffer)
                player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
                musicPlayer = player
            }
            _ = opts
            player.play()
            if !loop {
                // detach later roughly after duration
            }
        } catch {
            // fall through silent
        }
    }

    private func blip(engine: AVAudioEngine, frequency: Double, duration: Double, volume: Float) {
        let sampleRate = 22050.0
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = frameCount
        let twoPiF = 2.0 * Double.pi * frequency
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let env = Float(max(0, 1 - t / duration))
            data[i] = Float(sin(twoPiF * t)) * volume * env * env
        }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.scheduleBuffer(buffer, at: nil, options: []) { [weak engine, weak player] in
            if let player, let engine {
                engine.disconnectNodeOutput(player)
                engine.detach(player)
            }
        }
        player.play()
    }
}
#endif
