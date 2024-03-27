//
//  HoursRequest.swift
//  App
//
//  Created by basalaev on 20.01.2020.
//

import Foundation
import LoggerAPI

struct HoursRequest {
    enum Period: Equatable {
        case day
        case weak
        case custom(from: String, to: String)
        
        static func make(components: [String]) -> HoursRequest.Period? {
            guard !components.isEmpty else {
                return nil
            }
            
            if components.count == 1 {
                switch components[0] {
                case "day":
                    return .day
                case "weak":
                    return .weak
                default:
                    return nil
                }
            } else if let from = components.first, let to = components.last {
                return .custom(from: from, to: to)
            } else {
                return nil
            }
        }
        
        static func == (lhs: HoursRequest.Period, rhs: HoursRequest.Period) -> Bool {
            switch (lhs, rhs) {
            case (.day, .day):
                return true
            case (.weak, .weak):
                return true
            case (.custom, .custom):
                return true
            default:
                return false
            }
        }
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

        if let period = Period.make(components: components[safe: "period"]?.params ?? []) {
            self.period = period
        } else {
            self.period = .day
        }

        if let value = components[safe: "daysOffset"], let daysOffset = TimeInterval(value) {
            self.daysOffset = daysOffset
        } else {
            self.daysOffset = 0
        }    
    }
}
