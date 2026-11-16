// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Music + façade over `SFXManager`. Music and SFX volumes are separate; one mute gates both.
/// Uses AVAudioPlayer only (no AVAudioEngine graph mutations off-thread).
///
/// Session category is `.ambient` so the hardware silent switch is respected.
/// Simulator `simctl io recordVideo` does not capture app audio — during smoke we also
/// append a timeline to Documents/smoke_audio_events.txt so CI can mux music+SFX onto the mp4.
public final class JuiceSound: @unchecked Sendable {
    public static let shared = JuiceSound()

    private var sessionReady = false
    private var levelMusic: AVAudioPlayer?
    private var maskLayer: AVAudioPlayer?
    private var smokeLogURL: URL?
    private var smokeLogAnchor: TimeInterval?
    private let logLock = NSLock()

    private let musicVolumeKey = "neon_bandit.musicVolume"
    private let muteKey = "neon_bandit.audioMuted"

    /// 0…1. Persisted. Independent of SFX volume.
    public var musicVolume: Float {
        didSet {
            let v = max(0, min(1, musicVolume))
            if v != musicVolume { musicVolume = v; return }
            UserDefaults.standard.set(Double(v), forKey: musicVolumeKey)
            applyMusicVolumes()
        }
    }

    /// Convenience mirror of SFXManager.volume.
    public var sfxVolume: Float {
        get { SFXManager.shared.volume }
        set { SFXManager.shared.volume = newValue }
    }

    /// Mutes music + SFX. Persisted. Silent-switch still applies on top via ambient session.
    public var muted: Bool {
        didSet {
            UserDefaults.standard.set(muted, forKey: muteKey)
            SFXManager.shared.muted = muted
            SFXManager.shared.applyMuteState()
            applyMusicVolumes()
        }
    }

    public func toggleMute() {
        muted.toggle()
    }

    private init() {
        let mv = UserDefaults.standard.object(forKey: musicVolumeKey) as? Double
        musicVolume = Float(mv ?? 0.42)
        muted = UserDefaults.standard.bool(forKey: muteKey)
        SFXManager.shared.muted = muted
    }

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

    private var smokeAutoplay: Bool {
        ProcessInfo.processInfo.arguments.contains("-SmokeAutoplay")
    }

    public func prepare() {
        guard !sessionReady else {
            _ = SFXManager.shared.preload()
            return
        }
        #if os(iOS)
        // `.ambient` respects the hardware silent switch (user request). Smoke mux still
        // rebuilds the soundtrack offline from smoke_audio_events.txt.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        _ = SFXManager.shared.preload()
        sessionReady = true
    }

    /// Map legacy AssetKey SFX onto the juice pack when available; fall back to Generated/audio.
    public func play(_ key: AssetKey) {
        prepare()
        if playJuiceMapped(key) { return }
        guard let url = AssetManifest.audioURL(key) else { return }
        logSmoke("sfx \(key.rawValue)")
        playLegacyOneShot(url)
    }

    /// Title / logo ident — juice `startup_jingle`, else legacy title sting.
    public func playTitleSting() {
        prepare()
        // Smoke never needs the 5.5s jingle in-process (mux uses the events log / music bed).
        if smokeAutoplay {
            logSmoke("sfx startup_jingle")
            return
        }
        if SFXManager.shared.loadedCount > 0 {
            logSmoke("sfx startup_jingle")
            SFXManager.shared.playStartupJingle()
            return
        }
        play(.musicTitleSting)
    }

    public func playUITap() {
        prepare()
        logSmoke("sfx ui_tap")
        SFXManager.shared.playUITap()
    }

    public func playUIBack() {
        prepare()
        logSmoke("sfx ui_back")
        SFXManager.shared.playUIBack()
    }

    public func playStar(_ index: Int) {
        prepare()
        let names = ["star_1", "star_2", "star_3"]
        guard names.indices.contains(index) else { return }
        logSmoke("sfx \(names[index])")
        SFXManager.shared.playStar(index)
    }

    public func playJump() {
        prepare()
        logSmoke("sfx jump")
        SFXManager.shared.playJump()
    }

    public func playLand() {
        prepare()
        logSmoke("sfx land")
        SFXManager.shared.playLand()
    }

    public func playPounce() {
        prepare()
        logSmoke("sfx pounce_whoosh")
        SFXManager.shared.playPounce()
    }

    public func playStomp() {
        prepare()
        logSmoke("sfx stomp_crunch")
        SFXManager.shared.playStomp()
    }

    public func playCollect(combo: Int, loot: Bool) {
        prepare()
        logSmoke(loot ? "sfx loot_pickup" : "sfx coin_pickup")
        SFXManager.shared.playCollect(combo: combo, loot: loot)
    }

    public func playHurt() {
        prepare()
        logSmoke("sfx raccoon_hurt")
        SFXManager.shared.playHurt()
    }

    public func playKO() {
        prepare()
        logSmoke("sfx raccoon_ko")
        SFXManager.shared.playKO()
    }

    public func playMopAlert() {
        prepare()
        logSmoke("sfx mop_bot_alert")
        SFXManager.shared.playMopAlert()
    }

    public func playMopHit() {
        prepare()
        logSmoke("sfx mop_bot_hit")
        SFXManager.shared.playMopHit()
    }

    private var bossTreadLogged = false

    public func setBossTreadMoving(_ moving: Bool) {
        prepare()
        if moving, !bossTreadLogged {
            logSmoke("sfx boss_tread_rumble")
            bossTreadLogged = true
        }
        if !moving { bossTreadLogged = false }
        SFXManager.shared.setBossTreadMoving(moving)
    }

    public func startLevelMusic() {
        prepare()
        stopMusic()
        guard let url = AssetManifest.audioURL(.musicLevelLoop) else { return }
        logSmoke("music level_loop")
        levelMusic = loopPlayer(url: url, volume: effectiveMusicVolume)
    }

    public func setMaskModeMusic(_ on: Bool) {
        prepare()
        // Smoke: skip the extra mask music decode — keeps SpriteKit city textures resident
        // for the Mask Mode screenshot (CI blowout gate).
        if smokeAutoplay {
            if on { logSmoke("music mask_mode_layer") } else if maskLayer != nil { logSmoke("music_mask_off") }
            return
        }
        if on {
            guard maskLayer == nil,
                  let url = AssetManifest.audioURL(.musicMaskLayer) else { return }
            logSmoke("music mask_mode_layer")
            maskLayer = loopPlayer(url: url, volume: effectiveMusicVolume * 1.05)
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
        SFXManager.shared.stopAllLoops()
    }

    // MARK: - Mapping

    @discardableResult
    private func playJuiceMapped(_ key: AssetKey) -> Bool {
        guard SFXManager.shared.loadedCount > 0 else { return false }
        switch key {
        case .sfxJump:
            playJump(); return true
        case .sfxLand:
            playLand(); return true
        case .sfxPounce:
            playPounce(); return true
        case .sfxBellyFlop:
            // No dedicated flop clip — soft land thud.
            playLand(); return true
        case .sfxMopHit:
            playStomp(); return true
        case .sfxCollectShiny:
            playCollect(combo: 1, loot: false); return true
        case .sfxPlayerHit:
            playHurt(); return true
        case .sfxFail:
            playKO(); return true
        case .sfxUITap:
            playUITap(); return true
        case .sfxMopAlert:
            playMopAlert(); return true
        default:
            return false
        }
    }

    private var effectiveMusicVolume: Float {
        muted ? 0 : musicVolume
    }

    private func applyMusicVolumes() {
        let v = effectiveMusicVolume
        levelMusic?.volume = v
        maskLayer?.volume = v * 1.05
        if muted {
            levelMusic?.pause()
            maskLayer?.pause()
        } else {
            if let p = levelMusic, !p.isPlaying { p.play() }
            if let p = maskLayer, !p.isPlaying { p.play() }
        }
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

    private var legacyOneshots: [AVAudioPlayer] = []

    private func playLegacyOneShot(_ url: URL) {
        guard !muted else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = sfxVolume
            player.prepareToPlay()
            player.play()
            legacyOneshots.append(player)
            legacyOneshots.removeAll { !$0.isPlaying && $0 !== player }
            if legacyOneshots.count > 5 {
                let drop = legacyOneshots.count - 5
                for p in legacyOneshots.prefix(drop) { p.stop() }
                legacyOneshots.removeFirst(drop)
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
            if !muted { player.play() }
            return player
        } catch {
            return nil
        }
    }
}
#endif
