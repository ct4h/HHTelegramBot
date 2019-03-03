//
//  SubscriptionTimeRequestFactory.swift
//  App
//
//  Created by basalaev on 03/03/2019.
//

import Foundation

class SubscriptionTimeRequestFactory: InlineCommandsRequestFactory {

    let chatID: Int64
    let callbackData: String

    init(chatID: Int64, callbackData: String) {
        self.chatID = chatID
        self.callbackData = callbackData
    }

    var request: InlineCommandsRequest {
        let values = times.map { (time) -> InlineButtonData in
            let query = SubscriptionTimeRequest(callbackData: callbackData, time: time).query
            return InlineButtonData(title: "\(time):00", query: query)
        }

        return InlineCommandsRequest(context: callbackData.urlPath ?? callbackData,
                                     title: title,
                                     values: values)
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
