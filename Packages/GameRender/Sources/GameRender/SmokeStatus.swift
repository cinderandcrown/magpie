// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Written to the app Documents directory so `simulator_smoke.sh` can assert aliveness / FPS / milestones.
public struct SmokeStatus: Equatable, Sendable {
    public var phase: String
    /// `loading` while atlases warm; `ready` once title chrome is on screen.
    public var boot: String
    public var fpsAvg: Double
    public var fpsSamples: Int
    public var stomps: Int
    public var shinies: Int
    /// Sticky: Mask Mode has been entered at least once (milestone).
    public var mask: Bool
    /// Live: bandit is currently in Mask Mode (for 04 capture handshake).
    public var maskOn: Bool
    public var died: Bool
    public var won: Bool
    public var elapsed: Double
    /// Count of banned debug/placeholder SKLabel texts currently in the scene tree.
    /// CI fails if this is ever > 0 during smoke.
    public var debugLabels: Int
    public var combo: Int
    public var medals: Int
    public var map: Bool
    public var daily: Bool

    public init(
        phase: String = "title",
        boot: String = "loading",
        fpsAvg: Double = 0,
        fpsSamples: Int = 0,
        stomps: Int = 0,
        shinies: Int = 0,
        mask: Bool = false,
        maskOn: Bool = false,
        died: Bool = false,
        won: Bool = false,
        elapsed: Double = 0,
        debugLabels: Int = 0,
        combo: Int = 0,
        medals: Int = 0,
        map: Bool = false,
        daily: Bool = false
    ) {
        self.phase = phase
        self.boot = boot
        self.fpsAvg = fpsAvg
        self.fpsSamples = fpsSamples
        self.stomps = stomps
        self.shinies = shinies
        self.mask = mask
        self.maskOn = maskOn
        self.died = died
        self.won = won
        self.elapsed = elapsed
        self.debugLabels = debugLabels
        self.combo = combo
        self.medals = medals
        self.map = map
        self.daily = daily
    }

    public var line: String {
        String(
            format: "phase=%@ boot=%@ fps=%.1f samples=%d stomps=%d shinies=%d mask=%d maskOn=%d died=%d won=%d elapsed=%.1f debugLabels=%d combo=%d medals=%d map=%d daily=%d",
            phase, boot, fpsAvg, fpsSamples, stomps, shinies,
            mask ? 1 : 0, maskOn ? 1 : 0, died ? 1 : 0, won ? 1 : 0, elapsed, debugLabels,
            combo, medals, map ? 1 : 0, daily ? 1 : 0
        )
    }

    public static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return docs.appendingPathComponent("smoke_status.txt")
    }

    public func write() {
        try? line.write(to: Self.fileURL, atomically: true, encoding: .utf8)
    }

    /// Exact-match ban list for on-screen SKLabel text (case-insensitive).
    public static let bannedDebugTexts: Set<String> = [
        "STOMP",
        "MASK MODE",
        "MASK MODE STOMP",
        "CHECK",
        "NECK",
        "TUNING",
        "DEBUG",
        "BANK",
        "HIT",
        "TODO",
        "PLACEHOLDER",
        "TUNING MENU",
    ]
}
