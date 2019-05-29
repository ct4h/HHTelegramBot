//
//  HoursController.swift
//  App
//
//  Created by basalaev on 14/11/2018.
//

import Foundation
import Telegrammer
import Async
import LoggerAPI
import FluentSQL
import MySQL

protocol HoursControllerView {
    func sendHours(chatID: Int64, request: HoursPeriodRequest, date: Date, response: DBHoursResponse)
    func sendHours(chatID: Int64, error: Error)
}

protocol HoursControllerProvider: InlineCommandsHandler {
    func handle(chatID: Int64, query: String, view: HoursControllerView)
}

class HoursController: ParentController, CommandsHandler, InlineCommandsHandler {

    // MARK: - CommandsHandler

    var handlers: [Handler] {
        return [CommandHandler(commands: ["/hours"], callback: loadHours)]
//        return [AuthCommandHandler(bot: env.bot, commands: ["/hours"], callback: loadHours)]
    }
    
    private func loadHours(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        try inline(query: inlineContext, chatID: chatID, provider: nil)?.throwingSuccess({ (request) in
            try self.sendInlineCommands(chatID: chatID, request: request)
        })
    }

    // MARK: - InlineCommandsHandler

    var inlineContext: String {
        return "hours"
    }

    func inline(query: String, chatID: Int64, provider: InlineCommandsProvider?) throws -> Future<InlineCommandsRequest>? {
        Log.info("hours inline query \(query)")

        let factory: InlineCommandsRequestFactory

        if let request = HoursPeriodRequest(query: query) {
            if let provider = provider {
                provider(chatID, query)
            } else {
                handle(chatID: chatID, request: request, view: self)
            }
            return nil
        } else if let request = HoursGroupRequest(query: query) {
            factory = HoursPeriodsRequestFactory(chatID: chatID, parentRequest: request, worker: env.worker)
        } else if let request = HoursDepartmentRequest(query: query) {
            factory = HoursGroupsRequestFactory(chatID: chatID, parentRequest: request, container: env.container)
        } else if let request = HoursDepartmentsRequest(query: query) {
            factory = HoursDepartmentsRequestFactory(chatID: chatID, parentRequest: request, container: env.container)
        } else {
            return nil
        }

        return factory.request
    }
}

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

        env.container.newConnection(to: .mysql).whenSuccess { (connection) in
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
                    connection.close()

                    let response = result.hoursResponse

                    var result: DBHoursResponse = [:]

                    for user in users {
                        result[user] = response[user] ?? [:]
                    }

                    view.sendHours(chatID: chatID, request: request, date: reportDate, response: result)
                }

                promise.whenFailure { (error) in
                    connection.close()

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
