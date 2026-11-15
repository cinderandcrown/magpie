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
    public var mask: Bool
    public var died: Bool
    public var won: Bool
    public var elapsed: Double

    public init(
        phase: String = "title",
        boot: String = "loading",
        fpsAvg: Double = 0,
        fpsSamples: Int = 0,
        stomps: Int = 0,
        shinies: Int = 0,
        mask: Bool = false,
        died: Bool = false,
        won: Bool = false,
        elapsed: Double = 0
    ) {
        self.phase = phase
        self.boot = boot
        self.fpsAvg = fpsAvg
        self.fpsSamples = fpsSamples
        self.stomps = stomps
        self.shinies = shinies
        self.mask = mask
        self.died = died
        self.won = won
        self.elapsed = elapsed
    }

    public var line: String {
        String(
            format: "phase=%@ boot=%@ fps=%.1f samples=%d stomps=%d shinies=%d mask=%d died=%d won=%d elapsed=%.1f",
            phase, boot, fpsAvg, fpsSamples, stomps, shinies, mask ? 1 : 0, died ? 1 : 0, won ? 1 : 0, elapsed
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
}
