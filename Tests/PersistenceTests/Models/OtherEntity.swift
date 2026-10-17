//
//  OtherEntity.swift
//  Persistence
//

import CoreData
import Foundation

/// A second type, so the tests can prove `changes(for:)` filters by entity rather than firing
/// on any save at all.
@objc(OtherEntity)
final class OtherEntity: NSManagedObject {
    @NSManaged var id: String
}
