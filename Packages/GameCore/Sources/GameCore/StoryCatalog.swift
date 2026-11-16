// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

/// Loads `Assets/Story/Story.json` — single editable source for intro, districts, crew, chatter, PA.
public struct StoryCatalog: Equatable, Sendable, Codable {
    public struct IntroPanel: Equatable, Sendable, Codable {
        public var id: String
        public var caption: String
        public var artHint: String
    }

    public struct DistrictBeat: Equatable, Sendable, Codable {
        public var title: String
        public var flavor: String
    }

    public struct CrewMember: Equatable, Sendable, Codable {
        public var id: String
        public var name: String
        public var line: String
    }

    public struct MopLine: Equatable, Sendable, Codable {
        public var id: String
        public var file: String
        public var line: String
    }

    public var premise: String
    /// Short punchy line for title / intro — e.g. vigilante-of-trash tagline.
    public var tagline: String
    public var introPanels: [IntroPanel]
    public var districts: [String: DistrictBeat]
    public var crew: [CrewMember]
    public var mopChatter: [MopLine]
    public var paTaunts: [String]

    public static let empty = StoryCatalog(
        premise: "",
        tagline: "",
        introPanels: [],
        districts: [:],
        crew: [],
        mopChatter: [],
        paTaunts: []
    )

    public static func load() -> StoryCatalog {
        let candidates: [URL] = {
            var urls: [URL] = []
            if let u = Bundle.main.url(forResource: "Story", withExtension: "json", subdirectory: "Story") {
                urls.append(u)
            }
            if let u = Bundle.main.url(forResource: "Story", withExtension: "json") {
                urls.append(u)
            }
            // SPM / Linux tests: walk up from #file toward repo Assets/Story/Story.json
            var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            for _ in 0..<8 {
                let candidate = dir
                    .appendingPathComponent("Assets/Story/Story.json")
                if FileManager.default.fileExists(atPath: candidate.path) {
                    urls.append(candidate)
                    break
                }
                let alt = dir
                    .deletingLastPathComponent() // Sources
                    .deletingLastPathComponent() // GameCore
                    .deletingLastPathComponent() // Packages
                    .appendingPathComponent("Assets/Story/Story.json")
                if FileManager.default.fileExists(atPath: alt.path) {
                    urls.append(alt)
                    break
                }
                dir = dir.deletingLastPathComponent()
            }
            return urls
        }()
        for url in candidates {
            if let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(StoryCatalog.self, from: data) {
                return decoded
            }
        }
        return .empty
    }

    public func crew(id: String) -> CrewMember? {
        crew.first { $0.id == id }
    }

    public func district(id: DistrictID) -> DistrictBeat? {
        districts[id.rawValue]
    }

    public func paTaunt(index: Int) -> String {
        guard !paTaunts.isEmpty else { return "" }
        return paTaunts[abs(index) % paTaunts.count]
    }
}
