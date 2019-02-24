//
//  HoursPeriodRequest.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

struct HoursPeriodRequest {
    let groupRequest: HoursGroupRequest
    let period: HoursPeriod

    init(groupRequest: HoursGroupRequest, period: HoursPeriod) {
        self.groupRequest = groupRequest
        self.period = period
    }

    init?(query: String) {
        if let groupRequest = HoursGroupRequest(query: query) {
            self.groupRequest = groupRequest
        } else {
            return nil
        }

        if let value = query.urlParameters["p"], let period = HoursPeriod(rawValue: value) {
            self.period = period
        } else {
            return nil
        }
    }

    var query: String {
        return groupRequest.query.appendURL(parameter: "p", value: period.rawValue)
    }
}
