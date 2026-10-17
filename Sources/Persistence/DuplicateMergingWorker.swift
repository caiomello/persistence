//
//  DuplicateMergingWorker.swift
//  Persistence
//
//  Created by Caio Mello on 17.10.26.
//

import Foundation
import CoreData
import OSLog

final class DuplicateMergingWorker: Sendable {
    private let persistenceController: PersistenceController
    private let syncedManagedObjects: [any SyncedManagedObject.Type]

    private let logger = Logger(subsystem: "Persistence", category: "DuplicateMergingWorker")

    init(persistenceController: PersistenceController, syncedManagedObjects: [any SyncedManagedObject.Type]) {
        self.persistenceController = persistenceController
        self.syncedManagedObjects = syncedManagedObjects
    }

    func start() {
        let (triggers, continuation) = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))

        for managedObjectType in syncedManagedObjects {
            Task.detached {
                for await _ in self.persistenceController.changes(for: managedObjectType) {
                    continuation.yield()
                }
            }
        }

        Task.detached {
            for await _ in triggers {
                await self.run()
            }
        }
    }
}

// MARK: - Merging

extension DuplicateMergingWorker {
    private func run() async {
        for managedObjectType in syncedManagedObjects {
            do {
                try await mergeDuplicates(of: managedObjectType)
            } catch {
                logger.error("Failed to merge duplicates of \(managedObjectType): \(error)")
                return
            }
        }
    }

    private func mergeDuplicates<T: SyncedManagedObject>(of managedObjectType: T.Type) async throws {
        try await persistenceController.performInBackground { context in
            try self.mergeDuplicates(of: managedObjectType, in: context)
        }
    }

    private func mergeDuplicates<T: SyncedManagedObject>(of managedObjectType: T.Type, in context: NSManagedObjectContext) throws {
        let copiesByID = Dictionary(grouping: try duplicates(of: managedObjectType, in: context), by: \.id)

        var survivors: [T] = []

        for copies in copiesByID.values {
            let keyedCopies = copies.compactMap { copy in copy.uuid.map { (uuid: $0, copy: copy) } }

            guard keyedCopies.count == copies.count else { continue }

            let orderedCopies = keyedCopies.sorted { $0.uuid < $1.uuid }.map(\.copy)

            guard let survivor = orderedCopies.first else { continue }

            let losers = orderedCopies.dropFirst()

            for loser in losers {
                survivor.merge(loser)
            }

            for loser in losers {
                context.delete(loser)
            }

            survivors.append(survivor)
        }

        guard survivors.isEmpty == false else { return }

        context.processPendingChanges()

        do {
            try T.didMergeDuplicates(survivors, in: context)
        } catch {
            logger.error("Failed to finish merging duplicates of \(managedObjectType): \(error)")
        }

        try context.saveIfNeeded()
    }

    private func duplicates<T: SyncedManagedObject>(of managedObjectType: T.Type, in context: NSManagedObjectContext) throws -> [T] {
        let count = NSExpressionDescription()
        count.name = "count"
        count.expression = NSExpression(forFunction: "count:", arguments: [NSExpression(forKeyPath: "id")])
        count.expressionResultType = .integer64AttributeType

        let repeatedIDsRequest = NSFetchRequest<NSDictionary>()
        repeatedIDsRequest.entity = managedObjectType.entity()
        repeatedIDsRequest.resultType = .dictionaryResultType
        repeatedIDsRequest.propertiesToFetch = ["id", count]
        repeatedIDsRequest.propertiesToGroupBy = ["id"]
        repeatedIDsRequest.havingPredicate = NSPredicate(format: "%@ > 1", NSExpression(forVariable: "count"))

        let repeatedIDs = try context.fetch(repeatedIDsRequest).compactMap { $0["id"] }

        guard repeatedIDs.isEmpty == false else { return [] }

        let copiesRequest = NSFetchRequest<T>()
        copiesRequest.entity = managedObjectType.entity()
        copiesRequest.predicate = NSPredicate(format: "id IN %@", argumentArray: [repeatedIDs])

        return try context.fetch(copiesRequest)
    }
}
