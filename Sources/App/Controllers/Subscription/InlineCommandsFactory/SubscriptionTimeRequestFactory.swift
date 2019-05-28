//
//  SubscriptionTimeRequestFactory.swift
//  App
//
//  Created by basalaev on 03/03/2019.
//

import Foundation
import Vapor

class SubscriptionTimeRequestFactory: InlineCommandsRequestFactory {

    let chatID: Int64
    let callbackData: String
    let worker: Worker

    init(chatID: Int64, callbackData: String, worker: Worker) {
        self.chatID = chatID
        self.callbackData = callbackData
        self.worker = worker
    }

    var request: Future<InlineCommandsRequest> {
        let times = self.times
        let callbackData = self.callbackData
        let title = self.title

        let promise = worker.eventLoop.newPromise(InlineCommandsRequest.self)

        worker.eventLoop.execute {
            let values = times.map { (time) -> InlineButtonData in
                let query = SubscriptionTimeRequest(callbackData: callbackData, time: time).query
                return InlineButtonData(title: "\(time):00", query: query)
            }

            let request = InlineCommandsRequest(context: callbackData.urlPath ?? callbackData,
                                         title: title,
                                         values: values)
            
            promise.succeed(result: request)
        }

        return promise.futureResult
    }
}

private extension SubscriptionTimeRequestFactory {

    var times: [Int8] {
        return [10, 11, 12, 13, 20, 21, 22, 23]
    }

    var title: String {
        return "Выбери время получения:"
    }
}
