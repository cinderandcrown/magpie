// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import GameCore

/// Music + façade over `SFXManager` and `MusicManager`. Music and SFX volumes are separate; one mute gates both.
/// Uses AVAudioPlayer only (no AVAudioEngine graph mutations off-thread).
///
/// Session category is `.ambient` so the hardware silent switch is respected.
/// Simulator `simctl recordVideo` does not capture app audio — during smoke we also
/// append a timeline to Documents/smoke_audio_events.txt so CI can mux music+SFX onto the mp4.
public final class JuiceSound: @unchecked Sendable {
    public static let shared = JuiceSound()

    private var sessionReady = false
    private var smokeLogURL: URL?
    private var smokeLogAnchor: TimeInterval?
    private let logLock = NSLock()
    /// Wall-clock debounce so flop thud + real land (or double collide) can't log two
    /// "sfx land" lines within the CI <100ms double-land gate.
    private var lastLandLogUptime: TimeInterval = -1

    private let musicVolumeKey = "neon_bandit.musicVolume"
    private let muteKey = "neon_bandit.audioMuted"

    /// 0…1. Persisted. Independent of SFX volume.
    public var musicVolume: Float {
        didSet {
            let v = max(0, min(1, musicVolume))
            if v != musicVolume { musicVolume = v; return }
            UserDefaults.standard.set(Double(v), forKey: musicVolumeKey)
            MusicManager.shared.volume = v
            MusicManager.shared.applyMuteState()
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
            MusicManager.shared.muted = muted
            MusicManager.shared.applyMuteState()
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
        MusicManager.shared.volume = musicVolume
        MusicManager.shared.muted = muted
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
            _ = MusicManager.shared.preload()
            return
        }
        #if os(iOS)
        // `.ambient` respects the hardware silent switch (user request). Smoke mux still
        // rebuilds the soundtrack offline from smoke_audio_events.txt.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        _ = SFXManager.shared.preload()
        _ = MusicManager.shared.preload()
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

    /// Soft ember/whoosh under the Cinder & Crown publisher splash. Respects mute.
    public func playPublisherIdentWhoosh() {
        prepare()
        logSmoke("sfx publisher_ident_whoosh")
        SFXManager.shared.play("publisher_ident_whoosh", rate: 1.0, gain: 0.55)
    }

    /// Title / logo ident — juice `startup_jingle`, then crossfade menu theme.
    public func playTitleSting() {
        prepare()
        logSmoke("sfx startup_jingle")
        if SFXManager.shared.loadedCount > 0 {
            MusicManager.shared.stop()
            SFXManager.shared.playStartupJingle()
            MusicManager.shared.playTitleMenu(jingleFirst: true)
            logSmoke("music menu_theme")
            return
        }
        logSmoke("music level_loop")
        play(.musicTitleSting)
        MusicManager.shared.startMenu(smokeLogToken: "level_loop")
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

    public func playTallyTick() {
        prepare()
        logSmoke("sfx tally_tick")
        SFXManager.shared.playTallyTick()
    }

    public func playNewBest() {
        prepare()
        logSmoke("sfx new_best")
        SFXManager.shared.playNewBest()
    }

    public func playLevelUp() {
        prepare()
        logSmoke("sfx level_up")
        SFXManager.shared.playLevelUp()
    }

    public func playJump() {
        prepare()
        logSmoke("sfx jump")
        SFXManager.shared.playJump()
    }

    /// Raw Sim `.land` event for CI (before audible debounce). Gate on these, not `sfx land`.
    public func logRawLand() {
        guard smokeAutoplay else { return }
        logSmoke("sim land")
    }

    public func playLand() {
        prepare()
        let now = ProcessInfo.processInfo.systemUptime
        // Match Sim.landCooldown (0.12s): one audible land per airborne beat.
        if lastLandLogUptime >= 0, now - lastLandLogUptime < 0.12 {
            return
        }
        lastLandLogUptime = now
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
        MusicManager.shared.duckBriefly()
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
        MusicManager.shared.duckBriefly()
    }

    public func playKO() {
        prepare()
        logSmoke("sfx raccoon_ko")
        SFXManager.shared.playKO()
        MusicManager.shared.duckBriefly(depth: 0.5, duration: 0.55)
    }

    public func playMopAlert() {
        prepare()
        logSmoke("sfx mop_bot_alert")
        SFXManager.shared.playMopAlert()
    }

    /// Optional robotic VO lines from `Assets/Audio/voice/` (see README there).
    /// Picks a random existing file; silent no-op until ElevenLabs assets land.
    public func playMopChatter(_ files: [String]) {
        prepare()
        guard !files.isEmpty else { return }
        let pick = files[Int.random(in: 0..<files.count)]
        logSmoke("voice \(pick)")
        SFXManager.shared.playVoiceFile(pick)
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

    /// District gameplay bed (main+district rotation, or boss).
    public func startLevelMusic(district: DistrictID? = nil, boss: Bool = false) {
        prepare()
        let token: String
        if boss {
            token = "boss_theme"
        } else if let district {
            switch district {
            case .neonDocks: token = "docks_theme"
            case .arcadeRow: token = "arcade_row_theme"
            case .rooftops: token = "rooftops_theme"
            case .sewerGrid: token = "sewer_grid_theme"
            }
        } else {
            token = MusicManager.shared.hasSoundtrackPack ? "main_theme" : "level_loop"
        }
        logSmoke("music \(token)")
        MusicManager.shared.startGameplay(district: district, boss: boss, smokeLogToken: token)
    }

    public func setMaskModeMusic(_ on: Bool) {
        prepare()
        if on {
            logSmoke("music mask_mode_layer")
            MusicManager.shared.setMaskBed(true)
            MusicManager.shared.duckBriefly(depth: 0.35, duration: 0.5)
        } else {
            logSmoke("music_mask_off")
            MusicManager.shared.setMaskBed(false)
        }
    }

    public func stopMusic() {
        logSmoke("music_stop")
        MusicManager.shared.stop()
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
            if legacyOneshots.count > 6 {
                let drop = legacyOneshots.count - 6
                for p in legacyOneshots.prefix(drop) { p.stop() }
                legacyOneshots.removeFirst(drop)
            }
        } catch {
            // Missing/corrupt clip — ignore rather than crash the host.
        }
    }
}
#endif