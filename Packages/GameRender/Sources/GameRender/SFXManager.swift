// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Resolves and decodes every clip from `Assets/Audio/sfx/` (shipped as `Audio/sfx`).
/// Preload retains WAV bytes in RAM so `play()` never hits disk.
/// SFX volume is independent of music; mute is owned by `JuiceSound`.
public final class SFXManager: @unchecked Sendable {
    public static let shared = SFXManager()

    private struct ClipMeta: Sendable {
        var name: String
        var file: String
        var loop: Bool
        var data: Data
    }

    private var metas: [String: ClipMeta] = [:]
    private var loops: [String: AVAudioPlayer] = [:]
    /// Per-clip voice pool — reuse players instead of decoding a new one each play.
    private var oneshotPools: [String: [AVAudioPlayer]] = [:]
    private var poolCursor: [String: Int] = [:]
    private var lastPlayUptime: [String: TimeInterval] = [:]
    private var preloaded = false
    private let lock = NSLock()
    private let voicesPerClip = 3
    private let retriggerGuard: TimeInterval = 0.04

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

    /// Load every manifest entry into an in-memory `Data` cache.
    @discardableResult
    public func preload(bundle: Bundle = .main) -> Int {
        lock.lock()
        defer { lock.unlock() }
        if preloaded { return metas.count }
        guard let root = resolveRoot(bundle: bundle) else { return 0 }
        let manURL = root.appendingPathComponent("sfx_manifest.json")
        guard let manifestData = try? Data(contentsOf: manURL),
              let json = try? JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              let sounds = json["sounds"] as? [[String: Any]] else { return 0 }

        for entry in sounds {
            guard let name = entry["name"] as? String,
                  let file = entry["file"] as? String else { continue }
            let loop = (entry["loop"] as? Bool) ?? false
            let url = root.appendingPathComponent(file)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), !isDir.boolValue,
                  let wav = try? Data(contentsOf: url) else {
                continue
            }
            metas[name] = ClipMeta(name: name, file: file, loop: loop, data: wav)
        }
        preloaded = true
        return metas.count
    }

    public var loadedCount: Int {
        lock.lock(); defer { lock.unlock() }
        return metas.count
    }

    public func isLoop(_ name: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return metas[name]?.loop ?? false
    }

    // MARK: - Play

    private func makePlayer(from data: Data, loop: Bool) -> AVAudioPlayer? {
        guard let player = try? AVAudioPlayer(data: data) else { return nil }
        player.enableRate = true
        if loop {
            player.numberOfLoops = -1
        }
        player.prepareToPlay()
        return player
    }

    public func play(_ name: String, rate: Float = 1.0, gain: Float = 1.0) {
        _ = preload()
        lock.lock()
        let mutedNow = muted
        let vol = volume
        let pcm = metas[name]?.data
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastPlayUptime[name], now - last < retriggerGuard {
            lock.unlock()
            return
        }
        lastPlayUptime[name] = now
        lock.unlock()
        guard !mutedNow, let pcm else { return }

        lock.lock()
        var pool = oneshotPools[name] ?? []
        let player: AVAudioPlayer?
        if let idle = pool.first(where: { !$0.isPlaying }) {
            player = idle
        } else if pool.count < voicesPerClip, let created = makePlayer(from: pcm, loop: false) {
            pool.append(created)
            oneshotPools[name] = pool
            player = created
        } else if !pool.isEmpty {
            let idx = (poolCursor[name] ?? 0) % pool.count
            poolCursor[name] = idx + 1
            let reuse = pool[idx]
            reuse.stop()
            player = reuse
        } else if let created = makePlayer(from: pcm, loop: false) {
            oneshotPools[name] = [created]
            player = created
        } else {
            player = nil
        }
        lock.unlock()

        guard let player else { return }
        player.rate = max(0.5, min(2.0, rate))
        player.volume = max(0, min(1, vol * gain))
        player.currentTime = 0
        player.play()
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
        guard let pcm = metas[name]?.data,
              let player = makePlayer(from: pcm, loop: true) else { return }
        player.volume = volume * gain
        player.play()
        loops[name] = player
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
        for (_, pool) in oneshotPools {
            for p in pool where p.isPlaying { p.volume = v }
        }
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

    /// Play a one-shot from Audio/voice/ if present (MOP chatter).
    public func playVoiceFile(_ fileName: String) {
        lock.lock()
        let mutedNow = muted
        let vol = volume
        lock.unlock()
        guard !mutedNow else { return }
        let candidates: [URL] = {
            var urls: [URL] = []
            if let u = Bundle.main.url(forResource: fileName.replacingOccurrences(of: ".m4a", with: ""), withExtension: "m4a", subdirectory: "Audio/voice") {
                urls.append(u)
            }
            if let root = Bundle.main.resourceURL?.appendingPathComponent("Audio/voice").appendingPathComponent(fileName) {
                urls.append(root)
            }
            return urls
        }()
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let data = try? Data(contentsOf: url),
              let player = makePlayer(from: data, loop: false) else { return }
        player.volume = vol
        player.play()
        lock.lock()
        oneshotPools["voice"] = (oneshotPools["voice"] ?? []) + [player]
        lock.unlock()
    }

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

    public func playTallyTick() { play("tally_tick") }
    public func playNewBest() { play("new_best") }
    public func playLevelUp() { play("level_up") }

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