//
//  NSManagedObjectContext+ExtensionsTests.swift
//  Persistence
//

import CoreData
import Foundation
import Testing
@testable import Persistence

@MainActor
struct NSManagedObjectContextExtensionsTests {
    private let container: NSPersistentContainer

    private var context: NSManagedObjectContext { container.viewContext }

    init() throws {
        container = try TestModel.makeContainer()
    }
}

// MARK: - Saving

extension NSManagedObjectContextExtensionsTests {
    @Test("Saving with no pending changes does not touch the store")
    func doesNothingWithoutChanges() async throws {
        try #require(context.hasChanges == false)

        // expectedCount: 0 — the point of the guard is that no save happens at all, which is
        // stronger than merely not throwing.
        await confirmation("the context is saved", expectedCount: 0) { saved in
            let observer = NotificationCenter.default.addObserver(
                forName: .NSManagedObjectContextDidSave,
                object: context,
                queue: nil
            ) { _ in saved() }

            defer { NotificationCenter.default.removeObserver(observer) }

            #expect(throws: Never.self) {
                try context.saveIfNeeded()
            }
        }
    }

    @Test("Saving with pending changes commits them")
    func savesPendingChanges() throws {
        let entity = TestEntity(context: context)
        entity.id = "1"
        entity.name = "Sonic"

        try #require(context.hasChanges)

        try context.saveIfNeeded()

        #expect(context.hasChanges == false)
        #expect(try context.count(for: NSFetchRequest<TestEntity>(entityName: "TestEntity")) == 1)
    }
}

// MARK: - Failure

extension NSManagedObjectContextExtensionsTests {
    @Test("A failed save rethrows rather than being swallowed")
    func rethrowsOnFailure() {
        // `name` is mandatory and deliberately left unset, so validation fails on save.
        let entity = TestEntity(context: context)
        entity.id = "1"

        do {
            try context.saveIfNeeded()
            Issue.record("Expected the save to fail validation.")
        } catch let error as NSError {
            #expect(error.code == NSValidationMissingMandatoryPropertyError)
        }
    }

    @Test("A failed save leaves the changes pending")
    func failureLeavesChangesPending() {
        let entity = TestEntity(context: context)
        entity.id = "1"

        #expect(throws: (any Error).self) {
            try context.saveIfNeeded()
        }

        #expect(context.hasChanges)
    }
}
