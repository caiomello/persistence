//
//  PersistentStoreTests.swift
//  Persistence
//

import Foundation
import Testing
@testable import Persistence

struct PersistentStoreTests {
    /// These defaults name the SQLite file on disk, so changing one silently orphans an existing
    /// database. That is what makes them worth pinning.
    @Test("The default file names are stable")
    func defaultFileNames() {
        #expect(fileName(of: .local(modelConfiguration: "Config")) == "local")
        #expect(fileName(of: .cloudPrivate(modelConfiguration: "Config", cloudKitContainer: "Container")) == "private")
        #expect(fileName(of: .cloudShared(modelConfiguration: "Config", cloudKitContainer: "Container")) == "shared")
    }

    @Test("An explicit file name overrides the default")
    func explicitFileNames() {
        #expect(fileName(of: .local(modelConfiguration: "Config", fileName: "custom")) == "custom")
        #expect(fileName(of: .cloudPrivate(modelConfiguration: "Config", cloudKitContainer: "Container", fileName: "custom")) == "custom")
        #expect(fileName(of: .cloudShared(modelConfiguration: "Config", cloudKitContainer: "Container", fileName: "custom")) == "custom")
    }

    @Test("An in-memory store has no file name")
    func inMemoryHasNoFileName() {
        #expect(fileName(of: .inMemory(modelConfiguration: "Config")) == nil)
    }

    private func fileName(of store: PersistentStore) -> String? {
        switch store {
        case .inMemory: nil
        case .local(_, let fileName): fileName
        case .cloudPrivate(_, _, let fileName): fileName
        case .cloudShared(_, _, let fileName): fileName
        }
    }
}
