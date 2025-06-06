//
//  PersistentStore.swift
//  
//
//  Created by Caio Mello on 29.06.21.
//

import Foundation

/// An enumeration containing the different types of persistent store.
public enum PersistentStore {
    /// An in-memory store.
    /// - Parameters:
    ///   - modelConfiguration: The corresponding managed object model configuration.
    case inMemory(modelConfiguration: String)

    /// An on-device store for local caching.
    /// - Parameters:
    ///   - modelConfiguration: The corresponding managed object model configuration.
    ///   - name: An optional custom name for the SQLite file.
    case local(modelConfiguration: String, fileName: String = "local")

    /// A CloudKit-managed store for private data.
    /// - Parameters:
    ///   - modelConfiguration: The corresponding managed object model configuration.
    ///   - cloudKitContainer: The corresponding CloudKit container.
    ///   - name: An optional custom name for the SQLite file.
    case cloudPrivate(modelConfiguration: String, cloudKitContainer: String, fileName: String = "private")

    /// A CloudKit-managed store for shared data.
    /// - Parameters:
    ///   - modelConfiguration: The corresponding managed object model configuration.
    ///   - cloudKitContainer: The corresponding CloudKit container.
    ///   - name: An optional custom name for the SQLite file.
    case cloudShared(modelConfiguration: String, cloudKitContainer: String, fileName: String = "shared")
}
