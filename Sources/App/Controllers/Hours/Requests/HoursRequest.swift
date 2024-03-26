//
//  HoursRequest.swift
//  App
//
//  Created by basalaev on 20.01.2020.
//

import Foundation
import LoggerAPI

struct HoursRequest {
    enum Period: String {
        case day
        case weak
    }

    let customFields: [String]
    let customValues: [String]
    let departments: [String]
    let users: [String]
    let period: Period
    let daysOffset: TimeInterval

    init?(from message: String?) {
        guard let message = message else {
            Log.error("Message not found")
            return nil
        }

        let components = message.components(separatedBy: " --")

        customFields = components[safe: "customFields"]?.params ?? []
        customValues = components[safe: "customValues"]?.params ?? []
        departments = components[safe: "departments"]?.params ?? []
        users = components[safe: "users"]?.params ?? []

        if customFields.count == 0, customValues.count == 0, departments.count == 0 {
            Log.error("Filter params not found")
            return nil
        }

        if let value = components[safe: "period"]?.params.first, let period = Period(rawValue: value)  {
            self.period = period
        } else {
            Log.error("Period not found")
            return nil
        }

        if let value = components[safe: "daysOffset"], let daysOffset = TimeInterval(value) {
            self.daysOffset = daysOffset
        } else {
            self.daysOffset = 0
        }    
    }
}
