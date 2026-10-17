//
//  TestModel.swift
//  Persistence
//

import CoreData
import Foundation
@testable import Persistence

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
