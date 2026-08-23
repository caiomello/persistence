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

        let model = NSManagedObjectModel()
        model.entities = [entity, other]
        model.setEntities([entity, other], forConfigurationName: configurationName)

        return model
    }

    /// A controller backed by the shared model and a fresh in-memory store.
    static func makeController() throws -> PersistenceController {
        try PersistenceController(
            modelName: "Test",
            managedObjectModel: model,
            stores: [.inMemory(modelConfiguration: configurationName)]
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
