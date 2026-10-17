//
//  SyncedEntity.swift
//  Persistence
//

import CoreData
import Foundation
@testable import Persistence

/// Listed in `syncedManagedObjects:`. `merge(_:)` and `didMergeDuplicates(_:in:)` record what they
/// received in stored attributes, so the tests can read it back from the store.
@objc(SyncedEntity)
final class SyncedEntity: NSManagedObject, SyncedManagedObject {
    @NSManaged var id: String
    @NSManaged var uuid: UUID?
    @NSManaged var mergedUUIDs: String
    @NSManaged var copiesWhenMerged: Int64

    func merge(_ duplicate: SyncedEntity) {
        mergedUUIDs = [mergedUUIDs, duplicate.uuid?.uuidString ?? ""]
            .filter { $0.isEmpty == false }
            .joined(separator: ",")
    }

    static func didMergeDuplicates(_ survivors: [SyncedEntity], in context: NSManagedObjectContext) throws {
        for survivor in survivors {
            let request = NSFetchRequest<SyncedEntity>(entityName: "SyncedEntity")
            request.predicate = NSPredicate(format: "id == %@", survivor.id)
            survivor.copiesWhenMerged = Int64(try context.count(for: request))
        }
    }
}
