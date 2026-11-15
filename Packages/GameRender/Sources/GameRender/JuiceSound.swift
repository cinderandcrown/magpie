// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Plays Fire Fox audio from `Assets/Generated/audio/` by AssetKey.
public final class JuiceSound: @unchecked Sendable {
    public static let shared = JuiceSound()

    private var engine: AVAudioEngine?
    private var musicPlayer: AVAudioPlayerNode?
    private var maskLayerPlayer: AVAudioPlayerNode?
    private var ready = false
    private var players: [AVAudioPlayer] = []

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
        if let url = AssetManifest.audioURL(key) {
            playOneShot(url)
            return
        }
        // Tiny procedural fallback
        procedural(key)
    }

    public func playTitleSting() {
        play(.musicTitleSting)
    }

    public func startLevelMusic() {
        prepare()
        stopMusic()
        guard let url = AssetManifest.audioURL(.musicLevelLoop), let engine else {
            proceduralDrone()
            return
        }
        loopFile(url, into: &musicPlayer, engine: engine, volume: 0.55)
    }

    public func setMaskModeMusic(_ on: Bool) {
        prepare()
        guard let engine else { return }
        if on {
            guard maskLayerPlayer == nil,
                  let url = AssetManifest.audioURL(.musicMaskLayer) else { return }
            loopFile(url, into: &maskLayerPlayer, engine: engine, volume: 0.45)
        } else {
            maskLayerPlayer?.stop()
            if let p = maskLayerPlayer { engine.detach(p) }
            maskLayerPlayer = nil
        }
    }

    public func stopMusic() {
        musicPlayer?.stop()
        maskLayerPlayer?.stop()
        if let engine {
            if let musicPlayer { engine.detach(musicPlayer) }
            if let maskLayerPlayer { engine.detach(maskLayerPlayer) }
        }
        musicPlayer = nil
        maskLayerPlayer = nil
    }

    private func playOneShot(_ url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            players.append(player)
            players = players.filter { $0.isPlaying || $0 === player }
        } catch {
            // ignore
        }
    }

    private func loopFile(_ url: URL, into slot: inout AVAudioPlayerNode?, engine: AVAudioEngine, volume: Float) {
        do {
            let file = try AVAudioFile(forReading: url)
            let player = AVAudioPlayerNode()
            player.volume = volume
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)
            let frames = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames) else { return }
            try file.read(into: buffer)
            player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
            player.play()
            slot = player
        } catch {
            // ignore
        }
    }

    private func procedural(_ key: AssetKey) {
        guard let engine else { return }
        let (f, d, v): (Double, Double, Float) = {
            switch key {
            case .sfxJump: return (520, 0.07, 0.25)
            case .sfxLand: return (180, 0.05, 0.2)
            case .sfxCollectShiny: return (920, 0.1, 0.22)
            case .sfxPounce, .sfxBellyFlop: return (360, 0.08, 0.28)
            case .sfxWin: return (660, 0.3, 0.28)
            case .sfxFail: return (110, 0.25, 0.28)
            default: return (300, 0.05, 0.15)
            }
        }()
        blip(engine: engine, frequency: f, duration: d, volume: v)
    }

    private func proceduralDrone() {
        guard let engine else { return }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        let sr = 22050.0
        let frames = AVAudioFrameCount(sr * 2)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames
        for i in 0..<Int(frames) {
            let t = Double(i) / sr
            data[i] = Float(sin(2 * .pi * 110 * t) * 0.04 + sin(2 * .pi * 165 * t) * 0.03)
        }
        engine.connect(player, to: engine.mainMixerNode, format: format)
        player.scheduleBuffer(buffer, at: nil, options: [.loops], completionHandler: nil)
        player.play()
        musicPlayer = player
    }

    private func blip(engine: AVAudioEngine, frequency: Double, duration: Double, volume: Float) {
        let sr = 22050.0
        let frameCount = AVAudioFrameCount(sr * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sr, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let data = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frameCount
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sr
            let env = Float(max(0, 1 - t / duration))
            data[i] = Float(sin(2 * .pi * frequency * t)) * volume * env * env
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
