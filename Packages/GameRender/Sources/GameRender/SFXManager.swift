// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Preloads every clip from `Assets/Audio/sfx/` (shipped as `Audio/sfx` in the app bundle).
/// SFX volume is independent of music; mute is owned by `JuiceSound`.
public final class SFXManager: @unchecked Sendable {
    public static let shared = SFXManager()

    private struct ClipMeta: Sendable {
        var name: String
        var file: String
        var loop: Bool
        var url: URL
    }

    private var metas: [String: ClipMeta] = [:]
    /// Decoded PCM kept once per clip (no second AVAudioPlayer template copy).
    private var clipData: [String: Data] = [:]
    private var loops: [String: AVAudioPlayer] = [:]
    private var oneshots: [AVAudioPlayer] = []
    private var preloaded = false
    private let lock = NSLock()

    private let volumeKey = "neon_bandit.sfxVolume"

    /// 0…1. Persisted. Independent of music volume.
    public var volume: Float {
        didSet {
            let v = max(0, min(1, volume))
            if v != volume { volume = v; return }
            UserDefaults.standard.set(Double(v), forKey: volumeKey)
            applyLoopVolumes()
        }
    }

    /// When true, play/loop calls are no-ops (silent switch / JuiceSound mute).
    public var muted: Bool = false

    private init() {
        let stored = UserDefaults.standard.object(forKey: volumeKey) as? Double
        volume = Float(stored ?? 0.85)
    }

    // MARK: - Bundle lookup

    public static func sfxRoots(bundle: Bundle = .main) -> [URL] {
        var roots: [URL] = []
        if let res = bundle.resourceURL {
            roots.append(res.appendingPathComponent("Audio/sfx", isDirectory: true))
            roots.append(res.appendingPathComponent("Assets/Audio/sfx", isDirectory: true))
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        roots.append(cwd.appendingPathComponent("Assets/Audio/sfx", isDirectory: true))
        return roots
    }

    private func resolveRoot(bundle: Bundle) -> URL? {
        for root in Self.sfxRoots(bundle: bundle) {
            let man = root.appendingPathComponent("sfx_manifest.json")
            if FileManager.default.fileExists(atPath: man.path) {
                return root
            }
        }
        return nil
    }

    // MARK: - Preload

    /// Load manifest + buffer every WAV once so gameplay play() does not hit the bundle repeatedly.
    @discardableResult
    public func preload(bundle: Bundle = .main) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if preloaded { return clipData.count }
        guard let root = resolveRoot(bundle: bundle) else { return 0 }
        let manURL = root.appendingPathComponent("sfx_manifest.json")
        guard let data = try? Data(contentsOf: manURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sounds = json["sounds"] as? [[String: Any]] else { return 0 }

        for entry in sounds {
            guard let name = entry["name"] as? String,
                  let file = entry["file"] as? String else { continue }
            let loop = (entry["loop"] as? Bool) ?? false
            let url = root.appendingPathComponent(file)
            guard let bytes = try? Data(contentsOf: url), !bytes.isEmpty else { continue }
            metas[name] = ClipMeta(name: name, file: file, loop: loop, url: url)
            clipData[name] = bytes
        }
        preloaded = true
        return clipData.count
    }

    public var loadedCount: Int {
        lock.lock(); defer { lock.unlock() }
        return clipData.count
    }

    public func isLoop(_ name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return metas[name]?.loop ?? false
    }

    // MARK: - Play

    public func play(_ name: String, rate: Float = 1.0, gain: Float = 1.0) {
        _ = preload()
        lock.lock()
        let mutedNow = muted
        let vol = volume
        let data = clipData[name]
        lock.unlock()
        guard !mutedNow, let data else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.enableRate = true
            player.rate = max(0.5, min(2.0, rate))
            player.volume = max(0, min(1, vol * gain))
            player.prepareToPlay()
            player.play()
            lock.lock()
            oneshots.append(player)
            oneshots.removeAll { !$0.isPlaying && $0 !== player }
            if oneshots.count > 6 {
                let drop = oneshots.count - 6
                for p in oneshots.prefix(drop) { p.stop() }
                oneshots.removeFirst(drop)
            }
            lock.unlock()
        } catch {
            // Missing/corrupt — ignore.
        }
    }

    public func startLoop(_ name: String, gain: Float = 1.0) {
        _ = preload()
        lock.lock()
        defer { lock.unlock() }
        guard !muted else { return }
        if let existing = loops[name], existing.isPlaying {
            existing.volume = volume * gain
            return
        }
        guard let data = clipData[name] else { return }
        do {
            let player = try AVAudioPlayer(data: data)
            player.numberOfLoops = -1
            player.volume = volume * gain
            player.prepareToPlay()
            player.play()
            loops[name] = player
        } catch {
            // ignore
        }
    }

    public func stopLoop(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        loops[name]?.stop()
        loops[name] = nil
    }

    public func stopAllLoops() {
        lock.lock()
        defer { lock.unlock() }
        for (_, p) in loops { p.stop() }
        loops.removeAll()
    }

    private func applyLoopVolumes() {
        lock.lock()
        defer { lock.unlock() }
        let v = muted ? 0 : volume
        for (_, p) in loops { p.volume = v }
        for p in oneshots where p.isPlaying { p.volume = v }
    }

    public func applyMuteState() {
        applyLoopVolumes()
        if muted {
            lock.lock()
            defer { lock.unlock() }
            for (_, p) in loops { p.pause() }
        } else {
            lock.lock()
            defer { lock.unlock() }
            for (_, p) in loops where !p.isPlaying { p.play() }
        }
    }

    // MARK: - Gameplay helpers

    /// Coin/loot pickup with escalating pitch + combo_up tier stingers.
    public func playCollect(combo: Int, loot: Bool) {
        let base = loot ? "loot_pickup" : "coin_pickup"
        let steps = max(0, combo - 1)
        let rate = min(1.0 + Float(steps) * 0.07, 1.55)
        play(base, rate: rate)
        switch combo {
        case 2, 3:
            play("combo_up_1", rate: rate)
        case 4, 5:
            play("combo_up_2", rate: rate)
        case 6...:
            play(combo >= 8 ? "combo_heist" : "combo_up_3", rate: rate)
        default:
            break
        }
    }

    public func playJump() { play("jump") }
    public func playLand() { play("land") }
    public func playStomp() {
        play("stomp_crunch")
        play("mop_bot_break", gain: 0.9)
    }
    public func playPounce() { play("pounce_whoosh") }
    public func playHurt() { play("raccoon_hurt") }
    public func playKO() { play("raccoon_ko") }
    public func playMopAlert() { play("mop_bot_alert") }
    public func playMopHit() { play("mop_bot_hit") }
    public func playUITap() { play("ui_tap") }
    public func playUIBack() { play("ui_back") }
    public func playStartupJingle() { play("startup_jingle") }
    public func playStar(_ index: Int) {
        let names = ["star_1", "star_2", "star_3"]
        guard names.indices.contains(index) else { return }
        play(names[index])
    }

    public func setBossTreadMoving(_ moving: Bool) {
        if moving {
            startLoop("boss_tread_rumble", gain: 0.55)
        } else {
            stopLoop("boss_tread_rumble")
        }
    }

    public func playBossAttack() { play("boss_vacuum_cannon") }
    public func playBossDefeat() {
        stopLoop("boss_tread_rumble")
        play("boss_defeat")
    }
}
#endif
