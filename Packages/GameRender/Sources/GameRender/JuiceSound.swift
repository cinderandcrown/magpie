// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import UIKit

/// Tiny procedural sound bank — original tones, no third-party samples.
public final class JuiceSound: @unchecked Sendable {
    public static let shared = JuiceSound()

    private var engine: AVAudioEngine?
    private var ready = false

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

    public func play(_ kind: Kind) {
        prepare()
        guard let engine else { return }
        let (freq, dur, vol): (Double, Double, Float) = {
            switch kind {
            case .pounce: return (420, 0.06, 0.25)
            case .land: return (180, 0.05, 0.2)
            case .flop: return (140, 0.08, 0.3)
            case .hit: return (660, 0.07, 0.28)
            case .shiny: return (880, 0.09, 0.22)
            case .bank: return (520, 0.14, 0.28)
            case .mask: return (330, 0.22, 0.3)
            case .win: return (660, 0.28, 0.3)
            case .fail: return (110, 0.25, 0.28)
            }
        }()
        blip(engine: engine, frequency: freq, duration: dur, volume: vol)
    }

    public enum Kind {
        case pounce, land, flop, hit, shiny, bank, mask, win, fail
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
