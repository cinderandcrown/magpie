// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

/// Tiny deterministic RNG for Daily Heist layout / MOP desync (SplitMix64).
public struct SeededRNG: Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEAD_BEEF_CAFE_BABE : seed
    }

    public mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func nextDouble() -> Double {
        Double(nextUInt64() >> 11) / Double(1 << 53)
    }

    public mutating func nextInt(_ upper: Int) -> Int {
        guard upper > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(upper))
    }

    public mutating func shuffle<T>(_ values: inout [T]) {
        guard values.count > 1 else { return }
        for i in stride(from: values.count - 1, through: 1, by: -1) {
            let j = nextInt(i + 1)
            values.swapAt(i, j)
        }
    }
}
