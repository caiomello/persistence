//
//  DuplicateMonitorTests.swift
//  Persistence
//

import CoreData
import Foundation
import Testing
@testable import Persistence

/// Time limits throughout: a regression here would otherwise hang rather than fail, since the
/// wait for a merge never ends.
@Suite(.timeLimit(.minutes(1)))
struct DuplicateMonitorTests {
    private let controller: PersistenceController

    init() throws {
        controller = try TestModel.makeController(syncedManagedObjects: [SyncedEntity.self])
    }
}

// MARK: - Survivor

extension DuplicateMonitorTests {
    @Test("Copies of one id reduce to the copy with the lowest uuid")
    func survivorHasTheLowestUUID() async throws {
        let uuids = [UUID(), UUID(), UUID()]

        try await insertCopies(of: SyncedEntity.self, id: "1", uuids: uuids)
        try await waitForMerge(of: "1")

        #expect(try await snapshots(of: "1").map(\.uuid) == [uuids.min()])
    }

    @Test("The survivor's merge receives the losers in uuid order")
    func mergeReceivesTheLosersInUUIDOrder() async throws {
        let first = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let second = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let third = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000003"))

        try await insertCopies(of: SyncedEntity.self, id: "1", uuids: [third, first, second])
        try await waitForMerge(of: "1")

        let survivor = try #require(try await snapshots(of: "1").first)

        #expect(survivor.mergedUUIDs == [second, third])
    }

    @Test("The survivors are handed over after the losers are deleted")
    func didMergeDuplicatesSeesOnlyTheSurvivor() async throws {
        try await insertCopies(of: SyncedEntity.self, id: "1", uuids: [UUID(), UUID(), UUID()])
        try await waitForMerge(of: "1")

        let survivor = try #require(try await snapshots(of: "1").first)

        #expect(survivor.copiesWhenMerged == 1, "didMergeDuplicates(_:in:) still saw a loser, or never received the survivor.")
    }
}

// MARK: - Untouched

extension DuplicateMonitorTests {
    @Test("A group with a copy that has no uuid is left untouched")
    func groupWithoutUUIDIsUntouched() async throws {
        try await insertCopies(of: SyncedEntity.self, id: "withoutUUID", uuids: [UUID(), nil])
        try await insertCopies(of: SyncedEntity.self, id: "withUUID", uuids: [UUID(), UUID()])
        try await waitForMerge(of: "withUUID")

        #expect(try await snapshots(of: "withoutUUID").count == 2)
    }

    @Test("A row with a unique id is left untouched")
    func uniqueRowIsUntouched() async throws {
        try await insertCopies(of: SyncedEntity.self, id: "unique", uuids: [UUID()])
        try await insertCopies(of: SyncedEntity.self, id: "duplicated", uuids: [UUID(), UUID()])
        try await waitForMerge(of: "duplicated")

        let unique = try await snapshots(of: "unique")

        #expect(unique.count == 1)
        #expect(unique.first?.mergedUUIDs == [])
        #expect(unique.first?.copiesWhenMerged == 0)
    }

    @Test("A type not listed in syncedManagedObjects is left untouched")
    func unlistedTypeIsUntouched() async throws {
        try await insertCopies(of: UnlistedSyncedEntity.self, id: "1", uuids: [UUID(), UUID()])
        try await insertCopies(of: SyncedEntity.self, id: "1", uuids: [UUID(), UUID()])
        try await waitForMerge(of: "1")

        #expect(try await countCopies(of: UnlistedSyncedEntity.self, id: "1") == 2)
    }
}

// MARK: - Helpers

extension DuplicateMonitorTests {
    private struct CopySnapshot: Sendable {
        let uuid: UUID?
        let mergedUUIDs: [UUID]
        let copiesWhenMerged: Int64
    }

    private func insertCopies<T: SyncedManagedObject>(of managedObjectType: T.Type, id: String, uuids: [UUID?]) async throws {
        try await controller.performInBackground { context in
            for uuid in uuids {
                let copy = NSManagedObject(entity: T.entity(), insertInto: context)
                copy.setValue(id, forKey: "id")
                copy.setValue(uuid, forKey: "uuid")
            }

            try context.saveIfNeeded()
        }
    }

    private func countCopies<T: SyncedManagedObject>(of managedObjectType: T.Type, id: String) async throws -> Int {
        try await controller.performInBackground { context in
            let request = NSFetchRequest<T>()
            request.entity = T.entity()
            request.predicate = NSPredicate(format: "id == %@", id)
            return try context.count(for: request)
        }
    }

    private func snapshots(of id: String) async throws -> [CopySnapshot] {
        try await controller.performInBackground { context in
            let request = NSFetchRequest<SyncedEntity>(entityName: "SyncedEntity")
            request.predicate = NSPredicate(format: "id == %@", id)

            return try context.fetch(request).map { copy in
                CopySnapshot(
                    uuid: copy.uuid,
                    mergedUUIDs: copy.mergedUUIDs.split(separator: ",").compactMap { UUID(uuidString: String($0)) },
                    copiesWhenMerged: copy.copiesWhenMerged
                )
            }
        }
    }

    /// The monitor registers its observers in tasks of its own, so the save that creates the
    /// duplicates can land before anything is listening. Each poll saves another unique row to
    /// trigger a run regardless.
    private func waitForMerge(of id: String) async throws {
        while try await countCopies(of: SyncedEntity.self, id: id) > 1 {
            try await insertCopies(of: SyncedEntity.self, id: "nudge-\(UUID())", uuids: [UUID()])
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
