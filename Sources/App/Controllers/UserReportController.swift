//
//  UserReportController.swift
//  App
//
//  Created by basalaev on 26/01/2019.
//

import Foundation
import Telegrammer
import Async
import LoggerAPI
import Fluent
import FluentSQL
import MySQL

/**
 Контроллер формирует отчет по конкретному человеку
 */
class UserReportController: ParentController, CommandsHandler, InlineCommandsHandler {

    weak var delegate: HoursControllerProvider?

    // MARK: - CommandsHandler

    var handlers: [Handler] {
        return [CommandHandler(commands: ["/dayReport"], callback: userReport)]
//        return [AuthCommandHandler(bot: env.bot, commands: ["/dayReport"], callback: userReport)]
    }

    private func userReport(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message, let from = message.from, let username = from.username else {
            send(text: "Не удалось определить пользователя", updater: update)
            return
        }

        guard let reportDate = Date().zeroTimeDate else {
            return
        }

        env.container.newConnection(to: .mysql).whenSuccess { (connection) in
            _ = self.requestUsers(on: connection, username: username).flatMap { (users) -> Future<[(((User, TimeEntries), Issue), Project)]> in
                let builder = User.query(on: connection)
                    .filter(\User.status, .equal, 1)
                    .join(\CustomValue.customized_id, to: \User.id)
                    .join(\CustomField.id, to: \CustomValue.custom_field_id)
                    .filter(\CustomField.name, .equal, "Telegram аккаунт")
                    .filter(\CustomValue.value, .equal, username)
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

                    let text = self.prepareToDisplay(data: result, date: reportDate.stringYYYYMMdd)
                    Log.info("Convert to text \(text)")
                    _ = try self.send(chatID: message.chat.id, text: text)
                }   

                promise.whenFailure { (error) in
                    connection.close()

                    let errorText = "Не удалось выполнить запрос к базе"
                    self.sendIn(chatID: message.chat.id, text: errorText, error: error)
                }

                return promise
            }
        }
    }

    private func requestUsers(on connection: MySQLConnection, username: String) -> Future<[User]> {
        let builder = User.query(on: connection)
            .filter(\User.status == 1)
            .join(\CustomValue.customized_id, to: \User.id)
            .join(\CustomField.id, to: \CustomValue.custom_field_id)
            .filter(\CustomField.name, .equal, "Telegram аккаунт")
            .filter(\CustomValue.value, .equal, username)

        return builder.all()
    }

    // MARK: - InlineCommandsHandler

    var inlineContext: String {
        return "reports"
    }

    func inline(query: String, chatID: Int64, provider: InlineCommandsProvider?) throws -> Future<InlineCommandsRequest>? {
        Log.info("reports inline query \(query)")

        return try delegate?.inline(query: query, chatID: chatID, provider: { (chatID, query) in
            if let provider = provider {
                provider(chatID, query)
            } else {
                self.delegate?.handle(chatID: chatID, query: query, view: self)
            }
        })
    }
}

// MARK: - Handle subscription

private extension UserReportController {

    func handle(chatID: Int64, query: String) {
        delegate?.handle(chatID: chatID, query: query, view: self)
    }
}

extension UserReportController: HoursControllerView {

    func sendHours(chatID: Int64, request: HoursPeriodRequest, date: Date, response: DBHoursResponse) {
        let dateString = date.stringYYYYMMdd

        do {
            for (user, projects) in response {
                let userData = [user: projects]
                let text = self.prepareToDisplay(data: userData, date: dateString)
                _ = try self.send(chatID: chatID, text: text)
            }
        } catch {
            Log.error("\(error)")
        }
    }

    func sendHours(chatID: Int64, error: Error) {
        let errorText = "Не удалось выполнить команду /reports"
        sendIn(chatID: chatID, text: errorText, error: error)
    }
}

// MARK: - Data

private extension UserReportController {

    func prepareToDisplay(data: DBHoursResponse, date: String) -> String {
        var usersStrings: [String] = []

        let sortedUsers = data.keys.sorted(by: { $0.name < $1.name })

        for user in sortedUsers {
            let projects = data[user] ?? [:]
            let sortedProjects = projects.keys.sorted(by: { $0.name < $1.name })

            var projectsStrings: [String] = []
            var projectsTime: Float = 0

            for project in sortedProjects {
                Log.info("project \(project.name)")

                if let issues = projects[project] {
                    let sortedIssues = issues.keys.sorted(by: { ($0.id ?? 0) < ($1.id ?? 0) })

                    var issuesStrings: [String] = []
                    var issuesTime: Float = 0

                    for issue in sortedIssues {
                        var timeEntriesString: String = "Без комментариев"
                        var timeEntriesTime: Float = 0

                        if let timeEntries = issues[issue] {
                            timeEntriesString = timeEntries
                                .sorted(by: { ($0.id ?? 0) < ($1.id ?? 0) })
                                .map({ " • " + $0.comments })
                                .joined(separator: "\n")
                            timeEntriesTime = timeEntries.reduce(0, { $0 + $1.hours })
                        }

                        if let issueId = issue.id {
                            let issueString = "> [PM-\(issueId)](https://pm.handh.ru/issues/\(issueId)) | \(issue.subject) \(timeEntriesTime)h:\n\(timeEntriesString)"
                            issuesStrings.append(issueString)
                        }

                        issuesTime += timeEntriesTime
                    }

                    let projectString = "*\(project.name) \(issuesTime)h:*\n\(issuesStrings.joined(separator: "\n"))"
                    projectsStrings.append(projectString)

                    projectsTime += issuesTime
                }
            }

            let projectsSeparator = "\n\n"
            let userString = "*[\(date)] \(user.lastname) \(user.firstname): \(projectsTime)*\n\n\(projectsStrings.joined(separator: projectsSeparator))"
            usersStrings.append(userString)
        }

        let usersSeparator = "========================="

        if usersStrings.count == 1 {
            let userFeedback = usersStrings.first ?? ""
            return userFeedback + "\n\n" + usersSeparator
        } else {
            return usersStrings.joined(separator: "\n\n\(usersSeparator)\n\n")
        }
    }
}
