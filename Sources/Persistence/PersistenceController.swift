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

public final class PersistenceController {
    private let persistentContainer: NSPersistentContainer

    public init(model: String, cloudKitContainer: String, stores: [PersistentStore]) {
        let container = NSPersistentCloudKitContainer(name: model)

        let storeDescriptions: [NSPersistentStoreDescription] = stores.map { store in
            switch store {
            case .inMemory:
                let inMemoryStoreURL = URL(fileURLWithPath: "/dev/null")
                let inMemoryStoreDescription = NSPersistentStoreDescription(url: inMemoryStoreURL)
                return inMemoryStoreDescription

            case .local(let settings):
                let localStoreName = settings.name ?? "local"
                let localStoreURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(localStoreName).sqlite")

                let localStoreDescription = NSPersistentStoreDescription(url: localStoreURL)
                localStoreDescription.configuration = settings.configuration

                return localStoreDescription

            case .private(let settings):
                let privateStoreName = settings.name ?? "private"
                let privateStoreURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(privateStoreName).sqlite")

                let privateStoreDescription = NSPersistentStoreDescription(url: privateStoreURL)

                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainer)
                options.databaseScope = .private

                privateStoreDescription.cloudKitContainerOptions = options
                privateStoreDescription.configuration = settings.configuration

                return privateStoreDescription

            case .shared(let settings):
                let sharedStoreName = settings.name ?? "shared"
                let sharedStoreURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("\(sharedStoreName).sqlite")

                let sharedStoreDescription = NSPersistentStoreDescription(url: sharedStoreURL)

                let options = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudKitContainer)
                options.databaseScope = .shared

                sharedStoreDescription.cloudKitContainerOptions = options
                sharedStoreDescription.configuration = settings.configuration

                return sharedStoreDescription
            }
        }

        container.persistentStoreDescriptions = storeDescriptions

        // TODO: Update to async version when available.
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Failed to load persistent store with description:\n\(description)\nError:\(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        self.persistentContainer = container
    }
}

// MARK: - Operations

extension PersistenceController {
    public func performInForeground(_ block: @escaping (NSManagedObjectContext) throws -> Void) throws {
        try block(persistentContainer.viewContext)

        if persistentContainer.viewContext.hasChanges {
            try persistentContainer.viewContext.save()
        }
    }

    public func performInBackground(_ block: @escaping (NSManagedObjectContext) throws -> Void) async throws {
        try await persistentContainer.performBackgroundTask { context in
            context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
            try block(context)

            if context.hasChanges {
                try context.save()
            }
        }
    }
}

// MARK: - Change tracking

extension PersistenceController {
    public func publisher<T: NSManagedObject>(for managedObjectType: T.Type) -> AnyPublisher<Void, Never> {
        savePublisher(for: managedObjectType).merge(with: mergePublisher(for: managedObjectType)).eraseToAnyPublisher()
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
