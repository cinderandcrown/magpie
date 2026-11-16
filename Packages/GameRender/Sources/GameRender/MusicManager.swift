// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

#if canImport(AVFoundation)
import AVFoundation
import Foundation
import GameCore

/// ElevenLabs soundtrack from `Assets/Audio/music/` (shipped as `Audio/music`).
/// Crossfades between tracks; main / alt rotation in gameplay; district + boss beds.
public final class MusicManager: @unchecked Sendable {
    public static let shared = MusicManager()

    private enum Mode: Equatable {
        case idle
        case menu
        case gameplayMain(useAlt: Bool)
        case district(DistrictID)
        case boss
    }

    private static let trackFiles: [String: String] = [
        "menu_theme": "menu_theme.m4a",
        "main_theme": "main_theme.m4a",
        "main_theme_alt": "main_theme_alt.m4a",
        "docks_theme": "docks_theme.m4a",
        "arcade_row_theme": "arcade_row_theme.m4a",
        "rooftops_theme": "rooftops_theme.m4a",
        "sewer_grid_theme": "sewer_grid_theme.m4a",
        "boss_theme": "boss_theme.m4a",
    ]

    private var rootsChecked = false
    private var musicRoot: URL?
    private var legacyRoot: URL?
    private var activePlayer: AVAudioPlayer?
    private var crossfadeFrom: AVAudioPlayer?
    private var crossfadeTimer: Timer?
    private var rotationTimer: Timer?
    private var duckTimer: Timer?
    private var mode: Mode = .idle
    private var maskDuckOn = false
    private var briefDuckDepth: Float = 0
    private let crossfadeSeconds: TimeInterval = 1.25
    private let mainRotateInterval: TimeInterval = 100

    /// Owned by `JuiceSound` (persisted there).
    public var volume: Float = 0.42
    public var muted: Bool = false

    private init() {}

    // MARK: - Bundle

    public static func musicRoots(bundle: Bundle = .main) -> [URL] {
        var roots: [URL] = []
        if let res = bundle.resourceURL {
            roots.append(res.appendingPathComponent("Audio/music", isDirectory: true))
            roots.append(res.appendingPathComponent("Assets/Audio/music", isDirectory: true))
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        roots.append(cwd.appendingPathComponent("Assets/Audio/music", isDirectory: true))
        return roots
    }

    private func resolveRoots(bundle: Bundle = .main) {
        guard !rootsChecked else { return }
        rootsChecked = true
        for root in Self.musicRoots(bundle: bundle) {
            if FileManager.default.fileExists(atPath: root.appendingPathComponent("main_theme.m4a").path) {
                musicRoot = root
                break
            }
        }
        if let res = bundle.resourceURL {
            let gen = res.appendingPathComponent("Generated/audio", isDirectory: true)
            if FileManager.default.fileExists(atPath: gen.appendingPathComponent("level_loop.m4a").path) {
                legacyRoot = gen
            }
        }
        let cwdGen = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Assets/Generated/audio", isDirectory: true)
        if legacyRoot == nil,
           FileManager.default.fileExists(atPath: cwdGen.appendingPathComponent("level_loop.m4a").path) {
            legacyRoot = cwdGen
        }
    }

    @discardableResult
    public func preload(bundle: Bundle = .main) -> Bool {
        resolveRoots(bundle: bundle)
        return musicRoot != nil || legacyRoot != nil
    }

    public var hasSoundtrackPack: Bool { musicRoot != nil }

    private func url(for token: String) -> URL? {
        if let root = musicRoot, let file = Self.trackFiles[token] {
            let u = root.appendingPathComponent(file)
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        if token == "main_theme", let leg = legacyRoot {
            let u = leg.appendingPathComponent("level_loop.m4a")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        if token == "mask_layer", let leg = legacyRoot {
            let u = leg.appendingPathComponent("mask_mode_layer.m4a")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    private static func districtToken(_ district: DistrictID) -> String {
        switch district {
        case .neonDocks: return "docks_theme"
        case .arcadeRow: return "arcade_row_theme"
        case .rooftops: return "rooftops_theme"
        case .sewerGrid: return "sewer_grid_theme"
        }
    }

    private var effectiveVolume: Float {
        if muted { return 0 }
        var v = volume
        if maskDuckOn { v *= 0.62 }
        if briefDuckDepth > 0 { v *= max(0.2, 1 - briefDuckDepth) }
        return v
    }

    // MARK: - Public transport

    /// Title / hideout: SFX startup jingle is triggered by `JuiceSound`; this starts menu bed after a beat.
    public func playTitleMenu(jingleFirst: Bool) {
        preload()
        cancelRotation()
        if jingleFirst {
            // Jingle (~5.5 s) then crossfade menu loop.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.4) { [weak self] in
                self?.startMenu(smokeLogToken: "menu_theme")
            }
        } else {
            startMenu(smokeLogToken: "menu_theme")
        }
    }

    public func startMenu(smokeLogToken: String = "menu_theme") {
        mode = .menu
        cancelRotation()
        guard let u = url(for: "menu_theme") ?? url(for: "main_theme") else { return }
        crossfade(to: u, logToken: smokeLogToken)
    }

    public func startGameplay(district: DistrictID?, boss: Bool = false, smokeLogToken: String? = nil) {
        preload()
        cancelRotation()
        if boss {
            mode = .boss
            guard let u = url(for: "boss_theme") ?? url(for: "main_theme") else { return }
            crossfade(to: u, logToken: smokeLogToken ?? "boss_theme")
            return
        }
        if let district, hasSoundtrackPack, url(for: Self.districtToken(district)) != nil {
            mode = .district(district)
            let tok = Self.districtToken(district)
            guard let u = url(for: tok) else { return }
            crossfade(to: u, logToken: smokeLogToken ?? tok)
            return
        }
        mode = .gameplayMain(useAlt: false)
        guard let u = url(for: "main_theme") else { return }
        crossfade(to: u, logToken: smokeLogToken ?? "main_theme")
        scheduleMainRotation()
    }

    public func stop() {
        cancelRotation()
        crossfadeTimer?.invalidate()
        crossfadeTimer = nil
        duckTimer?.invalidate()
        duckTimer = nil
        activePlayer?.stop()
        crossfadeFrom?.stop()
        activePlayer = nil
        crossfadeFrom = nil
        mode = .idle
        maskDuckOn = false
        briefDuckDepth = 0
    }

    /// Brief dip under loud hero SFX (stomp / hurt / mask sting).
    public func duckBriefly(depth: Float = 0.42, duration: TimeInterval = 0.38) {
        guard !muted, activePlayer != nil else { return }
        briefDuckDepth = max(briefDuckDepth, depth)
        refreshPlayerVolume()
        duckTimer?.invalidate()
        duckTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.briefDuckDepth = 0
            self?.refreshPlayerVolume()
        }
        if let duckTimer {
            RunLoop.main.add(duckTimer, forMode: .common)
        }
    }

    public func setMaskBed(_ on: Bool) {
        maskDuckOn = on
        refreshPlayerVolume()
    }

    public func applyMuteState() {
        refreshPlayerVolume()
        if muted {
            activePlayer?.pause()
            crossfadeFrom?.pause()
        } else {
            if let p = activePlayer, !p.isPlaying { p.play() }
            if let p = crossfadeFrom, !p.isPlaying { p.play() }
        }
    }

    // MARK: - Crossfade

    private func crossfade(to url: URL, logToken: String) {
        _ = logToken // timeline logged by JuiceSound
        guard let incoming = try? AVAudioPlayer(contentsOf: url) else { return }
        incoming.numberOfLoops = -1
        incoming.volume = 0
        incoming.prepareToPlay()

        crossfadeTimer?.invalidate()
        crossfadeFrom = activePlayer
        activePlayer = incoming

        if !muted {
            incoming.play()
        }

        let steps = 25
        let stepInterval = crossfadeSeconds / Double(steps)
        let target = effectiveVolume
        var step = 0
        crossfadeTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            step += 1
            let t = Float(step) / Float(steps)
            let vol = self.effectiveVolume
            incoming.volume = vol * t
            self.crossfadeFrom?.volume = vol * (1 - t)
            if step >= steps {
                timer.invalidate()
                self.crossfadeFrom?.stop()
                self.crossfadeFrom = nil
                incoming.volume = self.effectiveVolume
            }
        }
        if let crossfadeTimer {
            RunLoop.main.add(crossfadeTimer, forMode: .common)
        }
    }

    private func refreshPlayerVolume() {
        let v = effectiveVolume
        activePlayer?.volume = v
        crossfadeFrom?.volume = v
    }

    private func scheduleMainRotation() {
        cancelRotation()
        guard hasSoundtrackPack, url(for: "main_theme_alt") != nil else { return }
        rotationTimer = Timer.scheduledTimer(withTimeInterval: mainRotateInterval, repeats: true) { [weak self] _ in
            self?.rotateMainAlt()
        }
        if let rotationTimer {
            RunLoop.main.add(rotationTimer, forMode: .common)
        }
    }

    private func cancelRotation() {
        rotationTimer?.invalidate()
        rotationTimer = nil
    }

    private func rotateMainAlt() {
        guard case .gameplayMain(let useAlt) = mode else { return }
        let nextAlt = !useAlt
        mode = .gameplayMain(useAlt: nextAlt)
        let token = nextAlt ? "main_theme_alt" : "main_theme"
        guard let u = url(for: token) else { return }
        crossfade(to: u, logToken: token)
    }
}
#endif