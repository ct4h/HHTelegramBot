//
//  HoursPeriodsRequestFactory.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation
import Vapor

class HoursPeriodsRequestFactory: InlineCommandsRequestFactory {

    let chatID: Int64
    let parentRequest: HoursGroupRequest
    let worker: Worker

    init(chatID: Int64, parentRequest: HoursGroupRequest, worker: Worker) {
        self.chatID = chatID
        self.parentRequest = parentRequest
        self.worker = worker
    }

    var request: Future<InlineCommandsRequest> {
        let periods = self.periods
        let parentRequest = self.parentRequest
        let title = self.title

        let promise = worker.eventLoop.newPromise(InlineCommandsRequest.self)

        worker.eventLoop.execute {
            let values = periods.map { (period) -> InlineButtonData in
                let query = HoursPeriodRequest(groupRequest: parentRequest, period: period).query
                return InlineButtonData(title: period.title, query: query)
            }

            let request = InlineCommandsRequest(context: parentRequest.context,
                                                title: title,
                                                values: values)
            promise.succeed(result: request)
        }

        return promise.futureResult
    }
}

private extension HoursPeriodsRequestFactory {

    var periods: [HoursPeriod] {
        return [.today, .yesterday, .weak]
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
        case .weak:
            return "За неделю"
        }
    }
}
