//
//  PersistenceControllerTests.swift
//  Persistence
//

import CoreData
import Foundation
import Testing
@testable import Persistence

@MainActor
struct PersistenceControllerTests {
    private let controller: PersistenceController

    private var context: NSManagedObjectContext { controller.foregroundContext }

    init() throws {
        controller = try TestModel.makeController()
    }
}

// MARK: - Initialization

extension PersistenceControllerTests {
    @Test("A loaded controller has a usable foreground context")
    func foregroundContextIsUsable() {
        #expect(context.persistentStoreCoordinator != nil)
    }

    @Test("An unresolvable model name throws rather than yielding a broken controller")
    func unresolvableModelNameThrows() {
        #expect(throws: PersistenceError.modelNotFound(name: "NoSuchModel")) {
            _ = try PersistenceController(
                modelName: "NoSuchModel",
                stores: [.inMemory(modelConfiguration: TestModel.configurationName)]
            )
        }
    }
}

// MARK: - Foreground

extension PersistenceControllerTests {
    @Test("Work in the foreground returns its result")
    func foregroundReturnsResult() throws {
        let count = try controller.performInForeground { context in
            try context.count(for: NSFetchRequest<TestEntity>(entityName: "TestEntity"))
        }

        #expect(count == 0)
    }

    @Test("Work in the foreground runs against the view context")
    func foregroundUsesTheViewContext() throws {
        let isViewContext = try controller.performInForeground { $0 == self.context }

        #expect(isViewContext)
    }

    @Test("An error thrown in the foreground propagates")
    func foregroundRethrows() {
        #expect(throws: TestError.thrown) {
            try controller.performInForeground { _ in throw TestError.thrown }
        }
    }
}

// MARK: - Background

extension PersistenceControllerTests {
    @Test("Work in the background returns its result")
    func backgroundReturnsResult() async throws {
        let count = try await controller.performInBackground { context in
            try context.count(for: NSFetchRequest<TestEntity>(entityName: "TestEntity"))
        }

        #expect(count == 0)
    }

    @Test("Work in the background runs off the view context")
    func backgroundUsesItsOwnContext() async throws {
        let isViewContext = try await controller.performInBackground { [context] in $0 == context }

        #expect(isViewContext == false)
    }

    @Test("An error thrown in the background propagates")
    func backgroundRethrows() async {
        await #expect(throws: TestError.thrown) {
            try await controller.performInBackground { _ in throw TestError.thrown }
        }
    }

    @Test("Work saved in the background is visible in the foreground")
    func backgroundWritesAreMergedIntoTheForeground() async throws {
        try await controller.performInBackground { context in
            let entity = TestEntity(context: context)
            entity.id = "1"
            entity.name = "Sonic"
            try context.saveIfNeeded()
        }

        let count = try context.count(for: NSFetchRequest<TestEntity>(entityName: "TestEntity"))

        #expect(count == 1)
    }
}

// MARK: - Helpers

private enum TestError: Error {
    case thrown
}
