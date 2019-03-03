//
//  HoursPeriodsRequestFactory.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

class HoursPeriodsRequestFactory: InlineCommandsRequestFactory {

    let chatID: Int64
    let parentRequest: HoursGroupRequest

    init(chatID: Int64, parentRequest: HoursGroupRequest) {
        self.chatID = chatID
        self.parentRequest = parentRequest
    }

    var request: InlineCommandsRequest {
        let values = periods.map { (period) -> InlineButtonData in
            let query = HoursPeriodRequest(groupRequest: parentRequest, period: period).query
            return InlineButtonData(title: period.title, query: query)
        }

        return InlineCommandsRequest(context: parentRequest.context,
                                     title: title,
                                     values: values)
    }
}

private extension HoursPeriodsRequestFactory {

    var periods: [HoursPeriod] {
        return [.today, .yesterday]
    }

    var title: String {
        return "Вебери период:"
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
