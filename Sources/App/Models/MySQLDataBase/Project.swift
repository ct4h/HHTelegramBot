//
//  Project.swift
//  App
//
//  Created by basalaev on 21/04/2019.
//

import Foundation
import FluentMySQL

final class Project: MySQLModel, Hashable {

    static let entity = "projects"

    var id: Int?
    var name: String
    var identifier: String

    init(id: Int, name: String, identifier: String) {
        self.id = id
        self.name = name
        self.identifier = identifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id
    }
}
