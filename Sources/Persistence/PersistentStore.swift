//
//  PersistentStore.swift
//  
//
//  Created by Caio Mello on 29.06.21.
//

import Foundation
import CloudKit

public enum PersistentStore {
    public struct Settings {
        let name: String?
        let configuration: String?

        init(name: String? = nil, configuration: String? = nil) {
            self.name = name
            self.configuration = configuration
        }

        static var `default` = Settings(name: nil, configuration: nil)
    }

    case inMemory
    case local(Settings)
    case `private`(Settings)
    case shared(Settings)

    var scope: CKDatabase.Scope? {
        switch self {
        case .inMemory:
            return nil
        case .local:
            return nil
        case .private:
            return .private
        case .shared:
            return .shared
        }
    }
}
