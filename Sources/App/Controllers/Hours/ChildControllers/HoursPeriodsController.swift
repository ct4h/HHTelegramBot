//
//  HoursPeriodsController.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation
import Telegrammer

class HoursPeriodsController: ParentController {

    func handle(chatID: Int64, messageID: Int?, request: HoursGroupRequest) throws {
        var buttons: [[InlineKeyboardButton]] = []
        for period in periods {
            let periodRequest = HoursPeriodRequest(groupRequest: request, period: period)

            buttons.append([InlineKeyboardButton(text: period.title, callbackData: periodRequest.query)])
        }

        try send(chatID: chatID,
                 messageID: messageID,
                 text: title,
                 keyboardMarkup: InlineKeyboardMarkup(inlineKeyboard: buttons))
    }
}

private extension HoursPeriodsController {

    var periods: [HoursPeriod] {
        return [.today, .yesterday]
    }

    var title: String {
        return "Какой отчет подготовить?"
    }
}

private extension HoursPeriod {

    var title: String {
        switch self {
        case .today:
            return "За сегодня"
        case .yesterday:
            return "За вчера"
        }
    }
}
