//
//  SyncedManagedObject.swift
//  Persistence
//
//  Created by Caio Mello on 17.10.26.
//

import Foundation
import CoreData

public protocol SyncedManagedObject: NSManagedObject, SendableMetatype {
    associatedtype Identifier: Hashable

    var id: Identifier { get }
    var uuid: UUID? { get }

    func merge(_ duplicate: Self)

    static func didMergeDuplicates(_ survivors: [Self], in context: NSManagedObjectContext) throws
}

public extension SyncedManagedObject {
    static func didMergeDuplicates(_ survivors: [Self], in context: NSManagedObjectContext) throws {}
}
