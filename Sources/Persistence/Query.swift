//
//  Query.swift
//  
//
//  Created by Caio Mello on 07.07.21.
//

import Foundation
import CoreData

public enum QueryError: Error {
    case objectNotFound
}

public protocol Query {
    associatedtype ManagedObjectType: NSManagedObject
    var predicate: NSPredicate? { get }
    var sortDescriptors: [NSSortDescriptor]? { get }
    var fetchRequest: NSFetchRequest<ManagedObjectType> { get }
}

public extension Query {
    var sortDescriptors: [NSSortDescriptor]? {
        return nil
    }

    var fetchRequest: NSFetchRequest<ManagedObjectType> {
        let request = NSFetchRequest<ManagedObjectType>(entityName: "\(ManagedObjectType.self)")
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        return request
    }

    func fetch(context: NSManagedObjectContext) throws -> [ManagedObjectType] {
        try context.fetch(fetchRequest)
    }

    func fetchFirst(context: NSManagedObjectContext) throws -> ManagedObjectType {
        guard let first = try context.fetch(fetchRequest).first else { throw QueryError.objectNotFound }
        return first
    }

    func count(context: NSManagedObjectContext) throws -> Int {
        try context.count(for: fetchRequest)
    }
}
