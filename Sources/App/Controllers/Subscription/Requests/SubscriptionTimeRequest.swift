//
//  SubscriptionTimeRequest.swift
//  App
//
//  Created by basalaev on 03/03/2019.
//

import Foundation

struct SubscriptionTimeRequest {
    let callbackData: String
    let time: Int8

    init(callbackData: String, time: Int8) {
        self.callbackData = callbackData
        self.time = time
    }

    init?(query: String) {
        guard let value = query.urlParameters["t"], let time = Int8(value) else {
            return nil
        }

        self.time = time
        self.callbackData = query.replacingOccurrences(of: "&t=\(time)", with: "")
    }

    var query: String {
        return callbackData.appendURL(parameter: "t", value: String(time))
    }
}
