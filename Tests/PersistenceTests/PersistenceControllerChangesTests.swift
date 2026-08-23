//
//  PersistenceControllerChangesTests.swift
//  Persistence
//

import CoreData
import Foundation
import Testing
@testable import Persistence

/// Time limits throughout: a regression here would otherwise hang rather than fail, since the
/// stream simply never emits.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PersistenceControllerChangesTests {
    private let controller: PersistenceController

    private var context: NSManagedObjectContext { controller.foregroundContext }

    init() throws {
        controller = try TestModel.makeController()
    }
}

// MARK: - Emitting

extension PersistenceControllerChangesTests {
    @Test("Saving a watched type emits a change")
    func emitsForTheWatchedType() async {
        let stream = controller.changes(for: TestEntity.self)

        // The bodies are methods rather than inline closures because
        // `group.addTask { @MainActor in … }` trips a region-isolation checker bug.
        let emitted = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await self.firstEmission(from: stream) }
            group.addTask { await self.saveRepeatedly() }

            let result = await group.next() ?? false
            group.cancelAll()

            return result
        }

        #expect(emitted)
    }
}

// MARK: - Filtering

extension PersistenceControllerChangesTests {
    @Test("Saving an unwatched type emits nothing")
    func ignoresOtherTypes() async throws {
        let stream = controller.changes(for: TestEntity.self)

        let emitted = Task { @MainActor in
            for await _ in stream { return true }
            return false
        }

        // Let the observers register before the saves that must be ignored.
        try await Task.sleep(for: .milliseconds(100))

        for index in 0..<5 {
            let other = OtherEntity(context: context)
            other.id = "\(index)"
            try context.saveIfNeeded()
        }

        try await Task.sleep(for: .milliseconds(100))

        emitted.cancel()

        #expect(await emitted.value == false, "changes(for:) fired for an entity it does not watch.")
    }
}

// MARK: - Termination

extension PersistenceControllerChangesTests {
    @Test("Cancelling the consumer finishes the stream")
    func cancellationFinishesTheStream() async {
        let stream = controller.changes(for: TestEntity.self)

        let consumer = Task { @MainActor in
            for await _ in stream {}
            return true
        }

        consumer.cancel()

        #expect(await consumer.value)
    }
}

// MARK: - Helpers

extension PersistenceControllerChangesTests {
    private func firstEmission(from stream: AsyncStream<Void>) async -> Bool {
        for await _ in stream { return true }
        return false
    }

    /// The stream registers its observers in a task of its own, so a single save can land before
    /// anything is listening. Saving on a loop closes that race without betting the test on a
    /// fixed sleep.
    private func saveRepeatedly() async -> Bool {
        while Task.isCancelled == false {
            insertTestEntity()
            try? context.saveIfNeeded()
            try? await Task.sleep(for: .milliseconds(5))
        }

        return false
    }

    private func insertTestEntity() {
        let entity = TestEntity(context: context)
        entity.id = UUID().uuidString
        entity.name = "Sonic"
    }
}
