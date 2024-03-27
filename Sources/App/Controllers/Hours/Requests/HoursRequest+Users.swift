//
//  HoursRequest+Users.swift
//  App
//
//  Created by basalaev on 20.01.2020.
//

import Foundation
import Async
import FluentSQL
import MySQL

// TODO: Добавить поддержку массивов

extension HoursRequest: UsersRequest {

    func all(on connection: MySQLDatabase.Connection) -> Future<[((User, EmailAddress), Department)]> {
        var builder = User.query(on: connection)
            .filter(\User.status == 1)
            .join(\EmailAddress.user_id, to: \User.id)
            .join(\PeopleInformation.user_id, to: \User.id)
            .join(\Department.id, to: \PeopleInformation.department_id)
            .alsoDecode(EmailAddress.self)
            .alsoDecode(Department.self)
        

        if let customField = customFields.first, let customValue = customValues.first {
            builder = builder
                .join(\CustomValue.customized_id, to: \User.id)
                .join(\CustomField.id, to: \CustomValue.custom_field_id)
                .filter(\CustomField.name, .equal, customField)
                .filter(\CustomValue.value, .equal, customValue)
        }

        if let department = departments.first {
            builder = builder
                .filter(\Department.name, .equal, department)
        }

        if customFields.contains("Филиал"), customValues.contains("Саранск") {
            builder = builder
                .filter(\Department.parent_id, .equal, 1)
        }

        return builder.all()
    }
}
