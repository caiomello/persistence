//
//  Untitled.swift
//  Persistence
//
//  Created by Caio Mello on 23.08.26.
//

import Foundation
import CoreData
import OSLog

private let logger = Logger(subsystem: "Persistence", category: "NSManagedObjectContext")

public extension NSManagedObjectContext {
    func saveIfNeeded() {
        guard hasChanges else { return }

        do {
            try save()
        } catch {
            logger.error("Failed to save context: \(error)")
        }
    }
}
