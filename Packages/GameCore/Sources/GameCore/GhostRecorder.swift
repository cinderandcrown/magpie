// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

/// Records compact bandit samples for Daily Heist ghost races (~10 Hz + facing flips).
public struct GhostRecorder: Sendable {
    public private(set) var samples: [GhostSamplePoint] = []
    private var lastSampleAt: Double = -1
    private var lastFacing: Int8 = 1
    public var sampleInterval: Double = 0.1

    public init() {}

    public mutating func reset() {
        samples.removeAll(keepingCapacity: true)
        lastSampleAt = -1
        lastFacing = 1
    }

    public mutating func capture(elapsed: Double, position: Vec2, facing: Double) {
        let face: Int8 = facing >= 0 ? 1 : -1
        let due = elapsed - lastSampleAt >= sampleInterval
        let flipped = face != lastFacing
        guard due || flipped || samples.isEmpty else { return }
        samples.append(GhostSamplePoint(
            t: Float(elapsed),
            x: Float(position.x),
            y: Float(position.y),
            facing: face
        ))
        lastSampleAt = elapsed
        lastFacing = face
    }
}

/// GameCore-local sample (mirrors Services.GhostSample without a package cycle).
public struct GhostSamplePoint: Codable, Equatable, Sendable {
    public var t: Float
    public var x: Float
    public var y: Float
    public var facing: Int8

    public init(t: Float, x: Float, y: Float, facing: Int8) {
        self.t = t
        self.x = x
        self.y = y
        self.facing = facing
    }
}

/// Playback helper — interpolate ghost pose at time `t`.
public enum GhostPlayback: Sendable {
    public static func pose(samples: [GhostSamplePoint], at t: Double) -> (Vec2, Double)? {
        guard let first = samples.first else { return nil }
        if t <= Double(first.t) {
            return (Vec2(Double(first.x), Double(first.y)), Double(first.facing))
        }
        guard let last = samples.last else { return nil }
        if t >= Double(last.t) {
            return (Vec2(Double(last.x), Double(last.y)), Double(last.facing))
        }
        for i in 0..<(samples.count - 1) {
            let a = samples[i]
            let b = samples[i + 1]
            let ta = Double(a.t)
            let tb = Double(b.t)
            if t >= ta && t <= tb {
                let u = tb > ta ? (t - ta) / (tb - ta) : 0
                let p = Vec2(
                    Double(a.x) + (Double(b.x) - Double(a.x)) * u,
                    Double(a.y) + (Double(b.y) - Double(a.y)) * u
                )
                return (p, Double(b.facing))
            }
        }
        return (Vec2(Double(last.x), Double(last.y)), Double(last.facing))
    }
}
