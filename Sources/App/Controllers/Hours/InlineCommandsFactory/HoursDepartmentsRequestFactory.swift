//
//  HoursDepartmentsRequestFactory.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

class HoursDepartmentsRequestFactory: InlineCommandsRequestFactory {

    let chatID: Int64
    let parentRequest: HoursDepartmentsRequest

    init(chatID: Int64, parentRequest: HoursDepartmentsRequest) {
        self.chatID = chatID
        self.parentRequest = parentRequest
    }

    var request: InlineCommandsRequest {
        let values = departments.map { (department) -> InlineButtonData in
            let query = HoursDepartmentRequest(departmentsRequest: parentRequest, department: department).query
            return InlineButtonData(title: department, query: query)
        }

        return InlineCommandsRequest(context: parentRequest.context,
                                     title: title,
                                     values: values)
    }
}

private extension HoursDepartmentsRequestFactory {

    var departments: [String] {
        var fields: Set<String> = []

        for user in Storage.shared.users {
            for field in user.custom_fields {
                fields.insert(field.name)
            }
        }

        var objects = Array(fields)
        objects.sort(by: { $0 < $1 })
        return objects
    }

    var title: String {
        return "Выбери департамент:"
    }
}
