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
    case inMemory

    /// An on-device store for local caching.
    /// - Parameters:
    ///   - configuration: The corresponding managed object model configuration.
    ///   - name: An optional custom name for the SQLite file.
    case local(configuration: String, fileName: String = "local")

    /// A CloudKit-managed store for private data.
    /// - Parameters:
    ///   - configuration: The corresponding managed object model configuration.
    ///   - name: An optional custom name for the SQLite file.
    case cloudPrivate(configuration: String, fileName: String = "private")

    /// A CloudKit-managed store for shared data.
    /// - Parameters:
    ///   - configuration: The corresponding managed object model configuration.
    ///   - name: An optional custom name for the SQLite file.
    case cloudShared(configuration: String, fileName: String = "shared")
}
