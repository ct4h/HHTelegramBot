//
//  PeopleInformation.swift
//  App
//
//  Created by basalaev on 21.01.2020.
//

import Foundation
import FluentMySQL

final class PeopleInformation: MySQLModel {
    static let entity = "people_information"

    var id: Int?
    var user_id: Int
    var department_id: Int?

    init(id: Int?, user_id: Int, department_id: Int?) {
        self.id = id
        self.user_id = user_id
        self.department_id = department_id
    }
}
