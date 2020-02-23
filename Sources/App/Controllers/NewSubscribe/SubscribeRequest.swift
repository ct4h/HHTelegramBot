//
//  SubscribeRequest.swift
//  App
//
//  Created by basalaev on 21.01.2020.
//

import Foundation
import LoggerAPI

struct SubscribeRequest {
    enum Days: String {
        case monday = "mon"
        case tuesday = "tue"
        case wednesday = "wed"
        case thursday = "thu"
        case friday = "fri"
        case saturday = "sat"
        case sunday = "sun"
    }

    let chatID: Int64
    let query: String
    let days: [Days]
    let time: Int
    let command: String

    init?(chatID: Int64, query: String) {
        self.chatID = chatID

        Log.info("Parse query \(query)")

        var components = query.components(separatedBy: " --")

        var days: [Days]

        // TODO: Добавить удаление аргументов
        if let commandArg = components[safe: "command"], let commandValue = commandArg.params.first {
            self.command = commandValue
            components.removeAll(where: { $0 == commandArg })
        } else {
            Log.info("command not found")
            return nil
        }

        if let scheduleDays = components[safe: "scheduleDays"] {
            let params = scheduleDays.params
            Log.info("days params \(params)")
            days = scheduleDays.params.compactMap { Days(rawValue: $0) }
            components.removeAll(where: { $0 == scheduleDays })
        } else {
            Log.info("scheduleDays not found")
            days = []
        }

        if days.isEmpty {
            Log.info("Days empty")
            return nil
        }

        self.days = days

        if let scheduleHours = components[safe: "scheduleHours"], let value = scheduleHours.params.first?.components(separatedBy: ":").first, let time = Int(value) {
            self.time = time
            components.removeAll(where: { $0 == scheduleHours })
        } else {
            Log.info("scheduleHours not found")
            return nil
        }

        components.remove(at: 0)
        self.query = "/\(self.command) --\(components.joined(separator: " --"))"

        Log.info("Parse query \(self.query)")
    }
}

