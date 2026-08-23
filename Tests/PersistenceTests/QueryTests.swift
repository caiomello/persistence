//
//  QueryTests.swift
//  Persistence
//

import CoreData
import Foundation
import Testing
@testable import Persistence

/// `@MainActor` because these exercise the container's view context, which is a main-queue context.
@MainActor
struct QueryTests {
    private let container: NSPersistentContainer

    private var context: NSManagedObjectContext { container.viewContext }

    init() throws {
        container = try TestModel.makeContainer()
    }
}

// MARK: - Building the fetch request

extension QueryTests {
    @Test("The entity name is derived from the managed object type")
    func entityNameComesFromTheType() {
        #expect(AllEntities().fetchRequest.entityName == "TestEntity")
    }

    @Test("The predicate is carried into the fetch request")
    func predicateIsCarriedOver() throws {
        let query = EntitiesNamed("Sonic")
        let predicate = try #require(query.fetchRequest.predicate)

        #expect(predicate == query.predicate)
    }

    @Test("Sort descriptors default to nil")
    func sortDescriptorsDefaultToNil() {
        #expect(AllEntities().sortDescriptors == nil)
        #expect(AllEntities().fetchRequest.sortDescriptors == nil)
    }

    @Test("Sort descriptors are carried into the fetch request")
    func sortDescriptorsAreCarriedOver() throws {
        let descriptors = try #require(EntitiesByIndex().fetchRequest.sortDescriptors)

        #expect(descriptors.count == 1)
        #expect(descriptors.first?.key == "sortIndex")
    }
}

// MARK: - Fetching

extension QueryTests {
    @Test("Fetching returns only the objects matching the predicate")
    func fetchReturnsMatches() throws {
        insert(id: "1", name: "Sonic")
        insert(id: "2", name: "Tails")
        insert(id: "3", name: "Sonic")

        let matches = try EntitiesNamed("Sonic").fetch(context: context)

        #expect(matches.count == 2)
        #expect(matches.allSatisfy { $0.name == "Sonic" })
    }

    @Test("Fetching returns nothing when the predicate matches nothing")
    func fetchReturnsEmptyWhenNothingMatches() throws {
        insert(id: "1", name: "Sonic")

        #expect(try EntitiesNamed("Knuckles").fetch(context: context).isEmpty)
    }

    @Test("Fetching applies the sort descriptors")
    func fetchIsSorted() throws {
        insert(id: "1", name: "Third", sortIndex: 3)
        insert(id: "2", name: "First", sortIndex: 1)
        insert(id: "3", name: "Second", sortIndex: 2)

        let sorted = try EntitiesByIndex().fetch(context: context)

        #expect(sorted.map(\.name) == ["First", "Second", "Third"])
    }
}

// MARK: - Fetching one

extension QueryTests {
    @Test("Fetching the first object returns a match")
    func fetchFirstReturnsAMatch() throws {
        insert(id: "1", name: "Sonic")

        #expect(try EntitiesNamed("Sonic").fetchFirst(context: context).id == "1")
    }

    @Test("Fetching the first object throws when there is no match")
    func fetchFirstThrowsWhenNothingMatches() {
        #expect(throws: QueryError.objectNotFound) {
            try EntitiesNamed("Knuckles").fetchFirst(context: context)
        }
    }
}

// MARK: - Counting

extension QueryTests {
    @Test("Counting returns the number of matching objects", arguments: 0...3)
    func countMatchesTheNumberInserted(count: Int) throws {
        for index in 0..<count {
            insert(id: "\(index)", name: "Sonic")
        }

        insert(id: "other", name: "Tails")

        #expect(try EntitiesNamed("Sonic").count(context: context) == count)
    }
}

// MARK: - Helpers

extension QueryTests {
    @discardableResult
    private func insert(id: String, name: String, sortIndex: Int64 = 0) -> TestEntity {
        let entity = TestEntity(context: context)
        entity.id = id
        entity.name = name
        entity.sortIndex = sortIndex
        return entity
    }
}

// MARK: - Test queries

private struct AllEntities: Query {
    typealias ManagedObjectType = TestEntity

    var predicate: NSPredicate? { nil }
}

private struct EntitiesNamed: Query {
    typealias ManagedObjectType = TestEntity

    let name: String

    init(_ name: String) {
        self.name = name
    }

    var predicate: NSPredicate? { NSPredicate(format: "name == %@", name) }
}

private struct EntitiesByIndex: Query {
    typealias ManagedObjectType = TestEntity

    var predicate: NSPredicate? { nil }
    var sortDescriptors: [NSSortDescriptor]? { [NSSortDescriptor(key: "sortIndex", ascending: true)] }
}
