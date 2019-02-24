//
//  HoursDepartmentsController.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation
import Telegrammer
import LoggerAPI

class HoursDepartmentsController: ParentController {

    func handle(chatID: Int64, messageID: Int?, request: HoursDepartmentsRequest) throws {
        var buttons: [[InlineKeyboardButton]] = []
        for department in departments {
            let departmentRequest = HoursDepartmentRequest(departmentsRequest: request,
                                                           department: department)

            buttons.append([InlineKeyboardButton(text: department, callbackData: departmentRequest.query)])
        }

        try send(chatID: chatID,
                 messageID: messageID,
                 text: title,
                 keyboardMarkup: InlineKeyboardMarkup(inlineKeyboard: buttons))
    }
}

private extension HoursDepartmentsController {

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
        return "Какой отчет подготовить?"
    }
}
