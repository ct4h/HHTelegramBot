//
//  HoursGroupsRequestFactory.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

class HoursGroupsRequestFactory: InlineCommandsRequestFactory {

    let chatID: Int64
    let parentRequest: HoursDepartmentRequest

    init(chatID: Int64, parentRequest: HoursDepartmentRequest) {
        self.chatID = chatID
        self.parentRequest = parentRequest
    }

    var request: InlineCommandsRequest {
        let values = groups(department: parentRequest.department).map { (group) -> InlineButtonData in
            let query = HoursGroupRequest(departmentRequest: parentRequest, group: group).query
            return InlineButtonData(title: group, query: query)
        }

        return InlineCommandsRequest(context: parentRequest.context,
                                     title: title,
                                     values: values)
    }
}

private extension HoursGroupsRequestFactory {

    func groups(department: String) -> [String] {
        var values: Set<String> = []

        for user in Storage.shared.users {
            for userField in user.custom_fields where userField.name == department && userField.value != "" {
                values.insert(userField.value)
            }
        }

        var objects = Array(values)
        objects.sort(by: { $0 < $1 })
        return objects
    }

    var title: String {
        return "Выбери группу пользователей:"
    }
}
