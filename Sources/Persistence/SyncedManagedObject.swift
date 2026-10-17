//
//  SyncedManagedObject.swift
//  Persistence
//
//  Created by Caio Mello on 17.10.26.
//

import Foundation
import CoreData

/// A managed object synced through CloudKit whose duplicate copies are merged into one.
///
/// Copies arise when the same item is created on two devices before they sync. Copies are grouped
/// by the entity's attribute named `id`, and the copy with the lowest `uuid` survives, so every
/// device keeps the same copy. List conforming types in `PersistenceController`'s
/// `syncedManagedObjects:` to have their duplicates merged.
public protocol SyncedManagedObject: NSManagedObject, SendableMetatype {
    associatedtype Identifier: Hashable

    /// The value shared by every copy of the same item, read from the entity's attribute named `id`.
    var id: Identifier { get }

    /// A value unique to each copy, set when the copy is created. A group in which any copy has no
    /// `uuid` is not merged.
    var uuid: UUID? { get }

    /// Folds a duplicate's state into this copy, the survivor.
    ///
    /// Called once per duplicate, in `uuid` order, before the duplicates are deleted.
    func merge(_ duplicate: Self)

    /// Called once each time this type is checked for duplicates, after any duplicates are deleted
    /// and before the context is saved.
    ///
    /// - Parameters:
    ///   - survivors: The copies that merged at least one duplicate. Empty when nothing merged.
    ///   - context: The context the merge ran in. Must not be saved here.
    /// - Throws: An error thrown here is logged, and the merge is still saved.
    static func didMergeDuplicates(_ survivors: [Self], in context: NSManagedObjectContext) throws
}

public extension SyncedManagedObject {
    /// Does nothing.
    static func didMergeDuplicates(_ survivors: [Self], in context: NSManagedObjectContext) throws {}
}
