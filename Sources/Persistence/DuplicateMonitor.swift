//
//  DuplicateMonitor.swift
//  Persistence
//
//  Created by Caio Mello on 17.10.26.
//

import Foundation
import CoreData
import OSLog

/// Merges duplicate copies of the listed types whenever any of them changes.
///
/// A run merges every listed type, one at a time, in list order. Changes that arrive during a run
/// collapse into a single follow-up run. A failure stops the run until the next change. The monitor
/// holds the controller strongly and runs for the life of the process.
final class DuplicateMonitor: Sendable {
    private let persistenceController: PersistenceController
    private let syncedManagedObjects: [any SyncedManagedObject.Type]

    private let logger = Logger(subsystem: "Persistence", category: "DuplicateMonitor")

    init(persistenceController: PersistenceController, syncedManagedObjects: [any SyncedManagedObject.Type]) {
        self.persistenceController = persistenceController
        self.syncedManagedObjects = syncedManagedObjects
    }

    /// Starts observing changes to the listed types. Call once.
    func start() {
        let (pendingRuns, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))

        for managedObjectType in syncedManagedObjects {
            Task.detached {
                for await _ in self.persistenceController.changes(for: managedObjectType) {
                    continuation.yield()
                }
            }
        }

        Task.detached {
            for await _ in pendingRuns {
                for managedObjectType in self.syncedManagedObjects {
                    do {
                        try await self.mergeDuplicates(of: managedObjectType)
                    } catch {
                        self.logger.error("Failed to merge duplicates of \(managedObjectType): \(error)")
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Merging

extension DuplicateMonitor {
    /// Merges the duplicates of one type in a background context.
    private func mergeDuplicates<T: SyncedManagedObject>(of managedObjectType: T.Type) async throws {
        try await persistenceController.performInBackground { context in
            try self.mergeDuplicates(of: managedObjectType, in: context)
        }
    }

    /// Keeps the copy with the lowest `uuid` for each repeated id, merges the others into it in
    /// `uuid` order, deletes them, calls `didMergeDuplicates(_:in:)`, and saves.
    private func mergeDuplicates<T: SyncedManagedObject>(of managedObjectType: T.Type, in context: NSManagedObjectContext) throws {
        let copiesByID = Dictionary(grouping: try duplicates(of: managedObjectType, in: context), by: \.id)

        var survivors: [T] = []

        for copies in copiesByID.values {
            let copiesWithUUID = copies.compactMap { copy in copy.uuid.map { (uuid: $0, copy: copy) } }

            guard copiesWithUUID.count == copies.count else { continue }

            let copiesInUUIDOrder = copiesWithUUID.sorted { $0.uuid < $1.uuid }.map(\.copy)

            guard let survivor = copiesInUUIDOrder.first else { continue }

            let losers = copiesInUUIDOrder.dropFirst()

            for loser in losers {
                survivor.merge(loser)
            }

            for loser in losers {
                context.delete(loser)
            }

            survivors.append(survivor)
        }

        context.processPendingChanges()

        do {
            try T.didMergeDuplicates(survivors, in: context)
        } catch {
            logger.error("Failed to finish merging duplicates of \(managedObjectType): \(error)")
        }

        try context.saveIfNeeded()
    }

    /// Every row whose `id` appears more than once, found with a grouped fetch so unique rows are
    /// never loaded. Rows with no `id` are never returned.
    private func duplicates<T: SyncedManagedObject>(of managedObjectType: T.Type, in context: NSManagedObjectContext) throws -> [T] {
        let copyCount = NSExpressionDescription()
        copyCount.name = "copyCount"
        copyCount.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
        copyCount.expressionResultType = .integer64AttributeType

        let repeatedIDsRequest = NSFetchRequest<NSDictionary>()
        repeatedIDsRequest.entity = managedObjectType.entity()
        repeatedIDsRequest.resultType = .dictionaryResultType
        repeatedIDsRequest.propertiesToFetch = ["id", copyCount]
        repeatedIDsRequest.propertiesToGroupBy = ["id"]
        repeatedIDsRequest.havingPredicate = NSPredicate(format: "%@ > 1", NSExpression(forVariable: "copyCount"))

        let repeatedIDs = try context.fetch(repeatedIDsRequest).compactMap { $0["id"] }

        guard repeatedIDs.isEmpty == false else { return [] }

        let copiesRequest = NSFetchRequest<T>()
        copiesRequest.entity = managedObjectType.entity()
        copiesRequest.predicate = NSPredicate(format: "id IN %@", argumentArray: [repeatedIDs])

        return try context.fetch(copiesRequest)
    }
}
