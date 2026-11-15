// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Plays Fire Fox audio from `Assets/Generated/audio/` by AssetKey.
/// Uses AVAudioPlayer only (no AVAudioEngine graph mutations off-thread).
public final class JuiceSound: @unchecked Sendable {
    public static let shared = JuiceSound()

    private var sessionReady = false
    private var oneshots: [AVAudioPlayer] = []
    private var levelMusic: AVAudioPlayer?
    private var maskLayer: AVAudioPlayer?

    private init() {}

    public func prepare() {
        guard !sessionReady else { return }
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        sessionReady = true
    }

    public func play(_ key: AssetKey) {
        prepare()
        guard let url = AssetManifest.audioURL(key) else { return }
        playOneShot(url)
    }

    public func playTitleSting() {
        play(.musicTitleSting)
    }

    public func startLevelMusic() {
        prepare()
        stopMusic()
        guard let url = AssetManifest.audioURL(.musicLevelLoop) else { return }
        levelMusic = loopPlayer(url: url, volume: 0.42)
    }

    public func setMaskModeMusic(_ on: Bool) {
        prepare()
        if on {
            guard maskLayer == nil,
                  let url = AssetManifest.audioURL(.musicMaskLayer) else { return }
            maskLayer = loopPlayer(url: url, volume: 0.45)
        } else {
            maskLayer?.stop()
            maskLayer = nil
        }
    }

    public func stopMusic() {
        levelMusic?.stop()
        maskLayer?.stop()
        levelMusic = nil
        maskLayer = nil
    }

    private func playOneShot(_ url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            oneshots.append(player)
            oneshots.removeAll { !$0.isPlaying && $0 !== player }
            // Hard cap — prevents AVAudioPlayer pile-up under autoplay stomps/SFX spam.
            if oneshots.count > 5 {
                let drop = oneshots.count - 5
                for p in oneshots.prefix(drop) { p.stop() }
                oneshots.removeFirst(drop)
            }
        } catch {
            // Missing/corrupt clip — ignore rather than crash the host.
        }
    }

    private func loopPlayer(url: URL, volume: Float) -> AVAudioPlayer? {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = volume
            player.prepareToPlay()
            player.play()
            return player
        } catch {
            return nil
        }
    }
}
#endif
