//
//  Department.swift
//  App
//
//  Created by basalaev on 21.01.2020.
//

import Foundation
import FluentMySQL

final class Department: MySQLModel {
    static let entity = "departments"

    var id: Int?
    var name: String

    init(id: Int, name: String) {
        self.id = id
        self.name = name
    }
}
