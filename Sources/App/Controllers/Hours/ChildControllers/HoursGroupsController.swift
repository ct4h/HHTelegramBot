//
//  HoursDepartmentController.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation
import Telegrammer

class HoursGroupsController: ParentController {

    func handle(chatID: Int64, messageID: Int?, request: HoursDepartmentRequest) throws {
        var buttons: [[InlineKeyboardButton]] = []
        for group in groups(department: request.department) {
            let groupRequest = HoursGroupRequest(departmentRequest: request, group: group)

            buttons.append([InlineKeyboardButton(text: group, callbackData: groupRequest.query)])
        }

        try send(chatID: chatID,
                 messageID: messageID,
                 text: title,
                 keyboardMarkup: InlineKeyboardMarkup(inlineKeyboard: buttons))
    }
}

private extension HoursGroupsController {

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
        return "Какой отчет подготовить?"
    }
}
