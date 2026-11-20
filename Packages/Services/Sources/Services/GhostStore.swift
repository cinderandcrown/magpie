// Copyright © 2026 Cinder and Crown LLC. All rights reserved.

import Foundation

#if canImport(CloudKit)
import CloudKit

/// CloudKit public database ghost store.
/// Record type `DailyGhost`: dayKey, playerID, displayName, score, seconds, samples (asset/data).
public final class CloudKitGhostStore: GhostStoreServing, @unchecked Sendable {
    public static let recordType = "DailyGhost"
    public static let shared = CloudKitGhostStore()

    private let container: CKContainer
    private let local = MockGhostStore()

    public init(containerID: String = "iCloud.com.cinderandcrown.magpie") {
        self.container = CKContainer(identifier: containerID)
    }

    public func saveOwnBest(_ run: GhostRun) async {
        await local.saveOwnBest(run)
        do {
            let recordID = CKRecord.ID(recordName: "\(run.dayKey)_\(run.playerID)")
            let record = CKRecord(recordType: Self.recordType, recordID: recordID)
            record["dayKey"] = run.dayKey as CKRecordValue
            record["playerID"] = run.playerID as CKRecordValue
            record["displayName"] = run.displayName as CKRecordValue
            record["score"] = run.score as CKRecordValue
            record["seconds"] = run.seconds as CKRecordValue
            if let data = try? JSONEncoder().encode(run.samples) {
                record["samples"] = data as CKRecordValue
            }
            _ = try await container.publicCloudDatabase.save(record)
        } catch {
            // Offline / unsigned — local mock already kept the best run.
        }
    }

    public func loadOwnBest(dayKey: String) async -> GhostRun? {
        if let local = await local.loadOwnBest(dayKey: dayKey) { return local }
        return nil
    }

    public func loadWorldBest(dayKey: String) async -> GhostRun? {
        do {
            let pred = NSPredicate(format: "dayKey == %@", dayKey)
            let query = CKQuery(recordType: Self.recordType, predicate: pred)
            query.sortDescriptors = [NSSortDescriptor(key: "score", ascending: false)]
            let (results, _) = try await container.publicCloudDatabase.records(
                matching: query,
                resultsLimit: 1
            )
            if let (_, result) = results.first, let record = try? result.get() {
                return decode(record)
            }
        } catch {}
        return await local.loadWorldBest(dayKey: dayKey)
    }

    public func loadFriendBest(dayKey: String, friendID: String) async -> GhostRun? {
        do {
            let id = CKRecord.ID(recordName: "\(dayKey)_\(friendID)")
            let record = try await container.publicCloudDatabase.record(for: id)
            return decode(record)
        } catch {
            return await local.loadFriendBest(dayKey: dayKey, friendID: friendID)
        }
    }

    private func decode(_ record: CKRecord) -> GhostRun? {
        guard
            let dayKey = record["dayKey"] as? String,
            let playerID = record["playerID"] as? String,
            let displayName = record["displayName"] as? String,
            let score = record["score"] as? Int
        else { return nil }
        let seconds = (record["seconds"] as? Float) ?? 0
        var samples: [GhostSample] = []
        if let data = record["samples"] as? Data {
            samples = (try? JSONDecoder().decode([GhostSample].self, from: data)) ?? []
        }
        return GhostRun(
            dayKey: dayKey,
            playerID: playerID,
            displayName: displayName,
            score: score,
            seconds: seconds,
            samples: samples
        )
    }
}
#else

public final class CloudKitGhostStore: GhostStoreServing, @unchecked Sendable {
    public static let shared = CloudKitGhostStore()
    private let local = MockGhostStore()
    private init() {}
    public func saveOwnBest(_ run: GhostRun) async { await local.saveOwnBest(run) }
    public func loadOwnBest(dayKey: String) async -> GhostRun? { await local.loadOwnBest(dayKey: dayKey) }
    public func loadWorldBest(dayKey: String) async -> GhostRun? { await local.loadWorldBest(dayKey: dayKey) }
    public func loadFriendBest(dayKey: String, friendID: String) async -> GhostRun? {
        await local.loadFriendBest(dayKey: dayKey, friendID: friendID)
    }
}
#endif
