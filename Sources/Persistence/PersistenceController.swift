//
//  PersistenceController.swift
//  
//
//  Created by Caio Mello on 22.06.21.
//

import Foundation
import CoreData
import CloudKit
import Combine
import OSLog

/// An object responsible for initializing persistent stores and providing mechanisms for data fetching and manipulation.
public final class PersistenceController {
    static private let logger = Logger(subsystem: "Persistence", category: "PersistenceController")

    private let persistentContainer: NSPersistentContainer

    /// Initializes persistent stores.
    /// - Parameters:
    ///   - modelName: The name of the managed object model.
    ///   - stores: The individual stores to be initialized.
    public init(modelName: String, stores: [PersistentStore]) throws {
        let container = NSPersistentCloudKitContainer(name: modelName)

        let applicationSupportDirectoryURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

        let storeDescriptions: [NSPersistentStoreDescription] = stores.map { store in
            switch store {
            case .inMemory(let modelConfiguration):
                let inMemoryStoreURL = URL(fileURLWithPath: "/dev/null")

                let inMemoryStoreDescription = NSPersistentStoreDescription(url: inMemoryStoreURL)
                inMemoryStoreDescription.configuration = modelConfiguration

                return inMemoryStoreDescription

            case .local(let modelConfiguration, let fileName):
                let localStoreURL = applicationSupportDirectoryURL.appendingPathComponent("\(fileName).sqlite")

                let localStoreDescription = NSPersistentStoreDescription(url: localStoreURL)
                localStoreDescription.configuration = modelConfiguration

                return localStoreDescription

            case .cloudPrivate(let modelConfiguration, let cloudKitContainer, let fileName):
                let privateStoreURL = applicationSupportDirectoryURL.appendingPathComponent("\(fileName).sqlite")

                let privateStoreDescription = NSPersistentStoreDescription(url: privateStoreURL)

                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainer)
                options.databaseScope = .private

                privateStoreDescription.cloudKitContainerOptions = options
                privateStoreDescription.configuration = modelConfiguration

                return privateStoreDescription

            case .cloudShared(let modelConfiguration, let cloudKitContainer, let fileName):
                let sharedStoreURL = applicationSupportDirectoryURL.appendingPathComponent("\(fileName).sqlite")

                let sharedStoreDescription = NSPersistentStoreDescription(url: sharedStoreURL)

                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainer)
                options.databaseScope = .shared

                sharedStoreDescription.cloudKitContainerOptions = options
                sharedStoreDescription.configuration = modelConfiguration

                return sharedStoreDescription
            }
        }

        container.persistentStoreDescriptions = storeDescriptions

        var loadError: Error?

        container.loadPersistentStores { description, error in
            if let error = error {
                Self.logger.error("Failed to load persistent store with description:\n\(description)\nError:\(error) - \(error)")
                loadError = error
            } else {
                Self.logger.notice("Persistent store loaded with description: \(description)")
            }
        }

        if let loadError {
            throw loadError
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        self.persistentContainer = container
    }
}

// MARK: - Operations

extension PersistenceController {
    public var foregroundContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    public func performInForeground<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) throws -> T {
        try block(persistentContainer.viewContext)
    }

    public func performInBackground<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await persistentContainer.performBackgroundTask { context in
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            return try block(context)
        }
    }
}

// MARK: - Change tracking

extension PersistenceController {
    public func publisher<T: NSManagedObject>(for managedObjectType: T.Type) -> AnyPublisher<Void, Never> {
        savePublisher(for: managedObjectType)
            .merge(with: mergePublisher(for: managedObjectType))
            .eraseToAnyPublisher()
    }

    private func savePublisher<T: NSManagedObject>(for managedObjectType: T.Type) -> AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectIDsNotification, object: persistentContainer.viewContext)
            .compactMap { self.containsChanges(to: T.self, notification: $0, context: self.persistentContainer.viewContext) ? () : nil }
            .eraseToAnyPublisher()
    }

    private func mergePublisher<T: NSManagedObject>(for managedObjectType: T.Type) -> AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: NSManagedObjectContext.didMergeChangesObjectIDsNotification, object: persistentContainer.viewContext)
            .compactMap { self.containsChanges(to: T.self, notification: $0, context: self.persistentContainer.viewContext) ? () : nil }
            .eraseToAnyPublisher()
    }

    private func containsChanges<T: NSManagedObject>(to type: T.Type, notification: NotificationCenter.Publisher.Output, context: NSManagedObjectContext) -> Bool {
        let updated = notification.userInfo?[NSUpdatedObjectIDsKey] as? Set<NSManagedObjectID> ?? []
        let inserted = notification.userInfo?[NSInsertedObjectIDsKey] as? Set<NSManagedObjectID> ?? []
        let deleted = notification.userInfo?[NSDeletedObjectIDsKey] as? Set<NSManagedObjectID> ?? []

        let changedIDs = updated.union(inserted).union(deleted)

        return changedIDs.contains { context.object(with: $0) is T }
    }
}
