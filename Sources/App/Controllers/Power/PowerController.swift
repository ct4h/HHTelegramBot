//
//  PowerController.swift
//  App
//
//  Created by basalaev on 08/06/2019.
//

import Foundation
import Telegrammer
import Async
import LoggerAPI
import Fluent
import FluentSQL
import MySQL

class PowerController: ParentController, CommandsHandler {

    // MARK: - CommandsHandler

    var handlers: [Handler] {
        return [CommandHandler(commands: ["/power"], callback: power)]
        //        return [AuthCommandHandler(bot: env.bot, commands: ["/hours"], callback: loadHours)]
    }

    private func power(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        env.container.requestCachedConnection(to: .mysql).whenSuccess { (connection) in
            let builder = TimeEntries.query(on: connection)

                .join(\User.id, to: \TimeEntries.user_id)
                .filter(\User.id, .equal, 285)
                .join(\Project.id, to: \TimeEntries.project_id)
                .filter(\Project.name, .equal, "ЯКИТОРИЯ | IOS")
                .join(\Issue.id, to: \TimeEntries.issue_id)
//                .group(._add, closure: { (builder) in
//                    builder.filter(\, <#T##method: MySQLBinaryOperator##MySQLBinaryOperator#>, <#T##value: Encodable##Encodable#>)
//                    builder.sum(\TimeEntries.hours)
//                })
                .groupBy(\TimeEntries.issue_id)
//            let users = try User.query(on: conn).group(.or) { or in
//                ///         or.filter(\.age < 18)
//                ///         or.filter(\.age > 65)
//                ///     }
//                .sum(\TimeEntries.hours)
//                .alsoDecode(Issue.self)

//                .filter(\User.status, .equal, 1)
//                .join(\CustomValue.customized_id, to: \User.id)
//                .join(\CustomField.id, to: \CustomValue.custom_field_id)
//                .filter(\CustomField.name, .equal, request.groupRequest.departmentRequest.department)
//                .filter(\CustomValue.value, .equal, request.groupRequest.group)
//                .join(\TimeEntries.user_id, to: \User.id)
//                .filter(\TimeEntries.spent_on, .equal, reportDate)
//                .join(\Issue.id, to: \TimeEntries.issue_id)
//                .join(\Project.id, to: \TimeEntries.project_id)
//                .alsoDecode(TimeEntries.self)
//                .alsoDecode(Issue.self)
//                .alsoDecode(Project.self)

            let promise = builder.all()

            promise.throwingSuccess { (result) in
//                let response = result.hoursResponse
//                var result: DBHoursResponse = [:]
//
//                for user in users {
//                    result[user] = response[user] ?? [:]
//                }
//
//                view.sendHours(chatID: chatID, request: request, date: reportDate, response: result)
            }

            promise.whenFailure { (error) in
//                view.sendHours(chatID: chatID, error: error)
            }
        }
    }
}

/*
extension HoursController: HoursControllerProvider {

    func handle(chatID: Int64, query: String, view: HoursControllerView) {
        guard let request = HoursPeriodRequest(query: query) else {
            return
        }

        handle(chatID: chatID, request: request, view: view)
    }

    private func handle(chatID: Int64, request: HoursPeriodRequest, view: HoursControllerView) {
        guard let reportDate = date(request: request).zeroTimeDate else {
            return
        }

        env.container.requestCachedConnection(to: .mysql).whenSuccess { (connection) in
            _ = self.requestUsers(on: connection, payload: request).flatMap { (users) -> Future<[(((User, TimeEntries), Issue), Project)]> in
                let builder = User.query(on: connection)
                    .filter(\User.status, .equal, 1)
                    .join(\CustomValue.customized_id, to: \User.id)
                    .join(\CustomField.id, to: \CustomValue.custom_field_id)
                    .filter(\CustomField.name, .equal, request.groupRequest.departmentRequest.department)
                    .filter(\CustomValue.value, .equal, request.groupRequest.group)
                    .join(\TimeEntries.user_id, to: \User.id)
                    .filter(\TimeEntries.spent_on, .equal, reportDate)
                    .join(\Issue.id, to: \TimeEntries.issue_id)
                    .join(\Project.id, to: \TimeEntries.project_id)
                    .alsoDecode(TimeEntries.self)
                    .alsoDecode(Issue.self)
                    .alsoDecode(Project.self)

                let promise = builder.all()

                promise.throwingSuccess { (result) in
                    let response = result.hoursResponse
                    var result: DBHoursResponse = [:]

                    for user in users {
                        result[user] = response[user] ?? [:]
                    }

                    view.sendHours(chatID: chatID, request: request, date: reportDate, response: result)
                }

                promise.whenFailure { (error) in
                    view.sendHours(chatID: chatID, error: error)
                }

                return promise
            }
        }
    }

    private func requestUsers(on connection: MySQLConnection, payload: HoursPeriodRequest) -> Future<[User]> {
        let builder = User.query(on: connection)
            .filter(\User.status == 1)
            .join(\CustomValue.customized_id, to: \User.id)
            .join(\CustomField.id, to: \CustomValue.custom_field_id)
            .filter(\CustomField.name, .equal, payload.groupRequest.departmentRequest.department)
            .filter(\CustomValue.value, .equal, payload.groupRequest.group)

        return builder.all()
    }
}

// MARK: - View

extension HoursController: HoursControllerView {

    func sendHours(chatID: Int64, request: HoursPeriodRequest, date: Date, response: DBHoursResponse) {
        guard chatID != 0 else {
            return
        }

        var usersInfo: [User: [TimeEntries]] = [:]

        for (user, projects) in response {
            var timeEntries = usersInfo[user] ?? []

            for (_, issues) in projects {
                for value in issues.values {
                    timeEntries += value
                }
            }

            usersInfo[user] = timeEntries
        }

        var users = Array(usersInfo.keys)
        users.sort(by: { $0.name < $1.name })

        let items = users.map { (user) -> String in
            let timeEntries = usersInfo[user] ?? []
            let time = Float(timeEntries.reduce(0, { $0 + $1.hours}))
            return "\(time.hoursIcon) \(user.name): \(time.hoursString)"
        }

        let department = request.groupRequest.departmentRequest.department
        let group = request.groupRequest.group

        let text = "Отчет \(department): \(group) за \(date.stringYYYYMMdd)\n\n" + items.joined(separator: "\n")

        do {
            _ = try self.send(chatID: chatID, text: text)
        } catch {
            Log.error("\(error)")
        }
    }

    func sendHours(chatID: Int64, error: Error) {
        let errorText = "Не удалось выполнить команду /hours"
        sendIn(chatID: chatID, text: errorText, error: error)
    }
}

// MARK: - Data

private extension HoursController {

    func date(request: HoursPeriodRequest) -> Date {
        let date: Date

        switch request.period {
        case .today:
            date = Date()
        case .yesterday:
            date = Date().addingTimeInterval(-86_400) // -сутки
        }

        return date
    }
}
*/
