//
//  TestEntity.swift
//  Persistence
//

import CoreData
import Foundation

/// A managed object used only by the tests.
///
/// `@objc(TestEntity)` keeps the Objective-C class name unqualified, so it matches the entity
/// name `Query` derives from the Swift type.
@objc(TestEntity)
final class TestEntity: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var name: String
    @NSManaged var sortIndex: Int64
}
