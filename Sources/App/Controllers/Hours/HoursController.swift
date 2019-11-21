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
    func sendHours(chatID: Int64, request: HoursPeriodRequest, date: (from: Date?, to: Date?), response: DBHoursResponse)
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
                Log.info("Forward query \(query) to provider")
                provider(chatID, query)
            } else {
                Log.info("Handle request")
                handle(chatID: chatID, request: request, view: self)
            }
            return nil
        } else if let request = HoursGroupRequest(query: query) {
            Log.info("HoursPeriodsRequestFactory")
            factory = HoursPeriodsRequestFactory(chatID: chatID, parentRequest: request, worker: env.worker)
        } else if let request = HoursDepartmentRequest(query: query) {
            Log.info("HoursGroupsRequestFactory")
            factory = HoursGroupsRequestFactory(chatID: chatID, parentRequest: request, container: env.container)
        } else if let request = HoursDepartmentsRequest(query: query) {
            Log.info("HoursDepartmentsRequestFactory")
            factory = HoursDepartmentsRequestFactory(chatID: chatID, parentRequest: request, container: env.container)
        } else {
            Log.info("nil")
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
        let reportDate = date(request: request)

        Log.info("[1] report date \(reportDate)")

        requestUsers(payload: request)
            .then { (users) -> EventLoopFuture<([User], DBHoursResponse)> in
                return self.requestTimeEntries(request: request, reportDate: reportDate)
                    .map { (users, $0) }
            }
            .whenSuccess { (response) in
                let users = response.0
                let hours = response.1

                var result: DBHoursResponse = [:]

                for user in users {
                    result[user] = hours[user] ?? [:]
                }

                view.sendHours(chatID: chatID, request: request, date: reportDate, response: result)
            }
    }

    private func requestUsers(payload: HoursPeriodRequest) -> Future<[User]> {
        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection,[User])>? in
                let builder = User.query(on: connection)
                    .filter(\User.status == 1)
                    .join(\CustomValue.customized_id, to: \User.id)
                    .join(\CustomField.id, to: \CustomValue.custom_field_id)
                    .filter(\CustomField.name, .equal, payload.groupRequest.departmentRequest.department)
                    .filter(\CustomValue.value, .equal, payload.groupRequest.group)
                return builder
                    .all()
                    .map { (connection, $0) }
            }
            .map({ (result) -> [User] in
                result.0.close()
                return result.1
            })
    }

    private func requestTimeEntries(request: HoursPeriodRequest, reportDate: (from: Date?, to: Date?)) -> Future<DBHoursResponse> {
        let fieldName = request.groupRequest.departmentRequest.department
        let fieldValue = request.groupRequest.group
        Log.info("[2] report date \(reportDate) CustomField.name \(fieldName) CustomValue.value \(fieldValue)")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection,DBHoursResponse)>? in
                var builder = User.query(on: connection)
                    .filter(\User.status, .equal, 1)
                    .join(\CustomValue.customized_id, to: \User.id)
                    .join(\CustomField.id, to: \CustomValue.custom_field_id)
                    .filter(\CustomField.name, .equal, fieldName)
                    .filter(\CustomValue.value, .equal, fieldValue)
                    .join(\TimeEntries.user_id, to: \User.id)
                    .join(\Issue.id, to: \TimeEntries.issue_id)
                    .join(\Project.id, to: \TimeEntries.project_id)
                    .alsoDecode(TimeEntries.self)
                    .alsoDecode(Issue.self)
                    .alsoDecode(Project.self)

                if let fromDate = reportDate.from, let toDate = reportDate.to {
                    builder = builder
                        .filter(\TimeEntries.spent_on, .greaterThanOrEqual, fromDate)
                        .filter(\TimeEntries.spent_on, .lessThan, toDate)
                } else if let reportDate = reportDate.to {
                    builder = builder
                        .filter(\TimeEntries.spent_on, .equal, reportDate)
                }

                return builder
                    .all()
                    .map { (connection, $0.hoursResponse) }
            }
            .map({ (result) -> DBHoursResponse in
                result.0.close()
                return result.1
            })
    }

    private func requestNicknames() -> Future<[CustomValue]> {
        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, [CustomValue])>? in
                let builder = CustomValue.query(on: connection)
                    .join(\CustomField.id, to: \CustomValue.custom_field_id)
                    .filter(\CustomField.name, .equal, "Telegram аккаунт")

                return builder
                    .all()
                    .map { (connection, $0) }
            }
            .map({ (result) -> [CustomValue] in
                result.0.close()
                return result.1
            })
    }
}

// MARK: - View

extension HoursController: HoursControllerView {

    func sendHours(chatID: Int64, request: HoursPeriodRequest, date: (from: Date?, to: Date?), response: DBHoursResponse) {
        guard chatID != 0, let date = date.to else {
            return
        }

        requestNicknames().whenSuccess { (nicknames) in
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

                var nickname: String = ""

                if time == 0 {
                    let nicknameValue = nicknames.first(where: { (nickname) -> Bool in
                        return user.id == nickname.customized_id
                    })

                    if let nicknameValue = nicknameValue {
                        if nicknameValue.value.first != "@" {
                            nickname = "@" + nicknameValue.value
                        } else {
                            nickname = nicknameValue.value
                        }
                    }

                    nickname = nickname.replacingOccurrences(of: "_", with: "\\_") + " "
                }

                return "\(time.hoursIcon) \(nickname)\(user.name): \(time.hoursString)"
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
    }

    func sendHours(chatID: Int64, error: Error) {
        let errorText = "Не удалось выполнить команду /hours"
        sendIn(chatID: chatID, text: errorText, error: error)
    }
}

// MARK: - Data

private extension HoursController {

    func date(request: HoursPeriodRequest) -> (from: Date?, to: Date?) {
        let fromDate: Date?
        let toDate: Date?

        switch request.period {
        case .today:
            fromDate = nil
            toDate = Date().zeroTimeDate
        case .yesterday:
            fromDate = nil
            toDate = Date().addingTimeInterval(-86_400).zeroTimeDate // -сутки
        case .weak:
            fromDate = Date().addingTimeInterval(-86_400 * 6).zeroTimeDate // начало неделю
            toDate = Date().addingTimeInterval(86_400).zeroTimeDate // конец недели
        }

        return (fromDate, toDate)
    }
}
