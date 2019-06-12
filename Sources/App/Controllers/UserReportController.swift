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

        requestUsers(username: username)
            .then { (users) -> EventLoopFuture<([User], DBHoursResponse)> in
                return self.requestTimeEntries(username: username, reportDate: reportDate)
                    .map { (users, $0) }
            }
            .whenSuccess { (response) in
                let users = response.0
                let hours = response.1

                var result: DBHoursResponse = [:]

                for user in users {
                    result[user] = hours[user] ?? [:]
                }

                let text = self.prepareToDisplay(data: result, date: reportDate.stringYYYYMMdd)
                Log.info("Convert to text \(text)")

                do {
                     _ = try self.send(chatID: message.chat.id, text: text)
                } catch {
                    Log.error("Error send message \(error)")
                }
            }
    }

    private func requestUsers(username: String) -> Future<[User]> {
        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection,[User])>? in
                let builder = User.query(on: connection)
                    .filter(\User.status == 1)
                    .join(\CustomValue.customized_id, to: \User.id)
                    .join(\CustomField.id, to: \CustomValue.custom_field_id)
                    .filter(\CustomField.name, .equal, "Telegram аккаунт")
                    .filter(\CustomValue.value, .equal, username)
                return builder
                    .all()
                    .map { (connection, $0) }
            }
            .map({ (result) -> [User] in
                result.0.close()
                return result.1
            })
    }

    private func requestTimeEntries(username: String, reportDate: Date) -> Future<DBHoursResponse> {
        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection,DBHoursResponse)>? in
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

                return builder
                    .all()
                    .map { (connection, $0.hoursResponse) }
            }
            .map({ (result) -> DBHoursResponse in
                result.0.close()
                return result.1
            })
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

                    let projectString = "*\(project.name) \(issuesTime.hoursString)h:*\n\(issuesStrings.joined(separator: "\n"))"
                    projectsStrings.append(projectString)

                    projectsTime += issuesTime
                }
            }

            let userString = "*[\(date)] \(user.lastname) \(user.firstname): \(projectsTime.hoursString)*"
            let projectsString = projectsStrings.joined(separator: "\n\n")

            if projectsString.isEmpty {
                usersStrings.append(userString)
            } else {
                usersStrings.append(userString + "\n\n" + projectsString)
            }
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
