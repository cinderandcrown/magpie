// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Plays Fire Fox audio from `Assets/Generated/audio/` by AssetKey.
/// Uses AVAudioPlayer only (no AVAudioEngine graph mutations off-thread).
///
/// Simulator `simctl io recordVideo` does not capture app audio — during smoke we also
/// append a timeline to Documents/smoke_audio_events.txt so CI can mux music+SFX onto the mp4.
public final class JuiceSound: @unchecked Sendable {
    public static let shared = JuiceSound()

    private var sessionReady = false
    private var oneshots: [AVAudioPlayer] = []
    private var levelMusic: AVAudioPlayer?
    private var maskLayer: AVAudioPlayer?
    private var smokeLogURL: URL?
    private var smokeLogAnchor: TimeInterval?
    private let logLock = NSLock()

    private init() {}

    public static var smokeAudioLogURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("smoke_audio_events.txt")
    }

    /// Start a fresh smoke audio timeline (call from beginPlay under -SmokeAutoplay).
    public func beginSmokeAudioLog() {
        logLock.lock()
        defer { logLock.unlock() }
        smokeLogURL = Self.smokeAudioLogURL
        smokeLogAnchor = ProcessInfo.processInfo.systemUptime
        try? "".write(to: Self.smokeAudioLogURL, atomically: true, encoding: .utf8)
        appendSmokeLineLocked("anchor 0.000")
    }

    public func prepare() {
        guard !sessionReady else { return }
        #if os(iOS)
        // `.playback` keeps music audible under silent-switch / smoke mux workflows.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        sessionReady = true
    }

    public func play(_ key: AssetKey) {
        prepare()
        guard let url = AssetManifest.audioURL(key) else { return }
        logSmoke("sfx \(key.rawValue)")
        playOneShot(url)
    }

    public func playTitleSting() {
        play(.musicTitleSting)
    }

    public func startLevelMusic() {
        prepare()
        stopMusic()
        guard let url = AssetManifest.audioURL(.musicLevelLoop) else { return }
        logSmoke("music level_loop")
        levelMusic = loopPlayer(url: url, volume: 0.42)
    }

    public func setMaskModeMusic(_ on: Bool) {
        prepare()
        if on {
            guard maskLayer == nil,
                  let url = AssetManifest.audioURL(.musicMaskLayer) else { return }
            logSmoke("music mask_mode_layer")
            maskLayer = loopPlayer(url: url, volume: 0.45)
        } else {
            if maskLayer != nil { logSmoke("music_mask_off") }
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

    private func logSmoke(_ token: String) {
        logLock.lock()
        defer { logLock.unlock() }
        guard smokeLogURL != nil, let anchor = smokeLogAnchor else { return }
        let t = ProcessInfo.processInfo.systemUptime - anchor
        appendSmokeLineLocked(String(format: "%.3f %@", t, token))
    }

    private func appendSmokeLineLocked(_ line: String) {
        guard let url = smokeLogURL else { return }
        let data = (line + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
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
