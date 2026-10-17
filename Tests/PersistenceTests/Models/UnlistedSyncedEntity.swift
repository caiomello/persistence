//
//  UnlistedSyncedEntity.swift
//  Persistence
//

import CoreData
import Foundation
@testable import Persistence

/// Conforms to `SyncedManagedObject` but is never listed in `syncedManagedObjects:`.
@objc(UnlistedSyncedEntity)
final class UnlistedSyncedEntity: NSManagedObject, SyncedManagedObject {
    @NSManaged var id: String
    @NSManaged var uuid: UUID?

    func merge(_ duplicate: UnlistedSyncedEntity) {}
}
