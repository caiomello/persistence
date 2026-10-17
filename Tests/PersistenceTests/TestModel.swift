//
//  TestModel.swift
//  Persistence
//

import CoreData
import Foundation
@testable import Persistence

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

/// A second type, so the tests can prove `changes(for:)` filters by entity rather than firing
/// on any save at all.
@objc(OtherEntity)
final class OtherEntity: NSManagedObject {
    @NSManaged var id: String
}

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

/// Conforms to `SyncedManagedObject` but is never listed in `syncedManagedObjects:`.
@objc(UnlistedSyncedEntity)
final class UnlistedSyncedEntity: NSManagedObject, SyncedManagedObject {
    @NSManaged var id: String
    @NSManaged var uuid: UUID?

    func merge(_ duplicate: UnlistedSyncedEntity) {}
}

enum TestModel {
    static let configurationName = "Test"

    /// One shared instance, deliberately. A managed object model is immutable once in use and
    /// safe to share, and building a fresh one per test would leave several live models all
    /// claiming the `TestEntity` class — which makes `+entity` ambiguous and silently inserts
    /// objects against the wrong entity.
    ///
    /// `nonisolated(unsafe)` because `NSManagedObjectModel` is not `Sendable`. It is built once
    /// here and only ever read afterwards, which is exactly the contract Core Data already
    /// requires of a model once it is attached to a coordinator.
    nonisolated(unsafe) static let model = makeModel()

    /// Built in code rather than loaded from a `.xcdatamodeld`, so the tests carry no resources
    /// and no bundle lookup.
    private static func makeModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "TestEntity"
        entity.managedObjectClassName = "TestEntity"

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .stringAttributeType
        id.isOptional = false

        // Mandatory and unset on insert, which is how the tests provoke a save failure.
        let name = NSAttributeDescription()
        name.name = "name"
        name.attributeType = .stringAttributeType
        name.isOptional = false

        let sortIndex = NSAttributeDescription()
        sortIndex.name = "sortIndex"
        sortIndex.attributeType = .integer64AttributeType
        sortIndex.isOptional = false
        sortIndex.defaultValue = 0

        entity.properties = [id, name, sortIndex]

        let other = NSEntityDescription()
        other.name = "OtherEntity"
        other.managedObjectClassName = "OtherEntity"

        let otherID = NSAttributeDescription()
        otherID.name = "id"
        otherID.attributeType = .stringAttributeType
        otherID.isOptional = false

        other.properties = [otherID]

        let synced = NSEntityDescription()
        synced.name = "SyncedEntity"
        synced.managedObjectClassName = "SyncedEntity"

        let syncedID = NSAttributeDescription()
        syncedID.name = "id"
        syncedID.attributeType = .stringAttributeType
        syncedID.isOptional = false

        let syncedUUID = NSAttributeDescription()
        syncedUUID.name = "uuid"
        syncedUUID.attributeType = .UUIDAttributeType
        syncedUUID.isOptional = true

        let mergedUUIDs = NSAttributeDescription()
        mergedUUIDs.name = "mergedUUIDs"
        mergedUUIDs.attributeType = .stringAttributeType
        mergedUUIDs.isOptional = false
        mergedUUIDs.defaultValue = ""

        let copiesWhenMerged = NSAttributeDescription()
        copiesWhenMerged.name = "copiesWhenMerged"
        copiesWhenMerged.attributeType = .integer64AttributeType
        copiesWhenMerged.isOptional = false
        copiesWhenMerged.defaultValue = 0

        synced.properties = [syncedID, syncedUUID, mergedUUIDs, copiesWhenMerged]

        let unlisted = NSEntityDescription()
        unlisted.name = "UnlistedSyncedEntity"
        unlisted.managedObjectClassName = "UnlistedSyncedEntity"

        let unlistedID = NSAttributeDescription()
        unlistedID.name = "id"
        unlistedID.attributeType = .stringAttributeType
        unlistedID.isOptional = false

        let unlistedUUID = NSAttributeDescription()
        unlistedUUID.name = "uuid"
        unlistedUUID.attributeType = .UUIDAttributeType
        unlistedUUID.isOptional = true

        unlisted.properties = [unlistedID, unlistedUUID]

        let entities = [entity, other, synced, unlisted]

        let model = NSManagedObjectModel()
        model.entities = entities
        model.setEntities(entities, forConfigurationName: configurationName)

        return model
    }

    /// A controller backed by the shared model and a fresh in-memory store.
    static func makeController(syncedManagedObjects: [any SyncedManagedObject.Type] = []) throws -> PersistenceController {
        try PersistenceController(
            modelName: "Test",
            managedObjectModel: model,
            stores: [.inMemory(modelConfiguration: configurationName)],
            syncedManagedObjects: syncedManagedObjects
        )
    }

    /// A fresh in-memory container per call, so suites running in parallel never share state.
    static func makeContainer() throws -> NSPersistentContainer {
        let container = NSPersistentContainer(name: "Test", managedObjectModel: model)

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: (any Error)?
        container.loadPersistentStores { _, error in loadError = error }
        if let loadError { throw loadError }

        return container
    }
}
