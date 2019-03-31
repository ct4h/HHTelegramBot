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

/**
 Контроллер формирует отчет по конкретному человеку
 */
class UserReportController: ParentController, CommandsHandler, InlineCommandsHandler {

    private lazy var paginationManager = {
        return PaginationManager<TimeEntriesResponse>(host: env.constants.redmine.domain,
                                                      port: env.constants.redmine.port,
                                                      access: env.constants.redmine.access,
                                                      worker: env.worker)
    }()

    weak var delegate: HoursControllerProvider?

    // MARK: - CommandsHandler

    var handlers: [Handler] {
        return [AuthCommandHandler(bot: env.bot, commands: ["/dayReport"], callback: userReport)]
    }

    private func userReport(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message, let from = message.from else {
            send(text: "Не удалось определить пользователя", updater: update)
            return
        }

        guard let user = searchUser(nickname: from.username) else {
            send(text: "Не удалось найти пользователя \(String(describing: from.username))", updater: update)
            return
        }

        let date = Date.stringYYYYMMdd

        let promise = paginationManager.all(requestFactory: { (offset, limit) -> ApiTarget in
            return RedmineRequest.timeEntries(userID: user.id, date: date, offset: offset, limit: limit)
        })

        promise.whenSuccess { [weak self] timeEntries in
            guard let self = self else {
                return
            }

            let report = self.displayData(timeEntries: timeEntries, user: user, date: date)
            self.send(text: report, updater: update)
        }

        promise.whenFailure { [weak self] error in
            let text = "Не удалось выполнить команду /dayReport"
            self?.sendIn(chatID: message.chat.id, text: text, error: error)
        }
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

    func sendHours(chatID: Int64, filter: FullUserField, date: String, response: [(FullUser, [TimeEntries])]) {
        response.forEach { (info) in
            let report = displayData(timeEntries: info.1, user: info.0, date: date)
            do {
                _ = try send(chatID: chatID, text: report)
            } catch {
                Log.error("\(error)")
            }
        }
    }

    func sendHours(chatID: Int64, error: Error) {
        let errorText = "Не удалось выполнить команду /reports"
        sendIn(chatID: chatID, text: errorText, error: error)
    }
}

// MARK: - Data

private extension UserReportController {

    func searchUser(nickname: String?) -> FullUser? {
        guard let nickname = nickname else {
            return nil
        }

        for user in Storage.shared.users {
            for field in user.custom_fields where field.value == nickname {
                return user
            }
        }

        return nil
    }

    func displayData(timeEntries: [TimeEntries], user: FullUser, date: String) -> String {
        var totalHours: Double = 0
        var reportProjects: [Project: [String]] = [:]

        for timeEntry in timeEntries {
            var comments: [String] = []

            if let values = reportProjects[timeEntry.project] {
                comments = values
            }

            totalHours += timeEntry.hours
            let comment = "[\(timeEntry.activity.name)] \(timeEntry.comments)"
            comments.append(comment)
            reportProjects[timeEntry.project] = comments
        }

        let separator = "*******************************"

        let projects = reportProjects.keys.sorted(by: { $0.name < $1.name })
        var reports: [String] = []
        for project in projects {
            if let values = reportProjects[project] {
                var comments = values.joined(separator: "\n")
                if comments.isEmpty {
                    comments = "Без комментариев"
                }
                let report = project.name + "\n" + comments + "\n" + separator
                reports.append(report)
            }
        }

        var report = "[\(date)] \(user.name): \(totalHours)"
        if !reports.isEmpty {
            report = report + "\n\n" + separator + "\n" + reports.joined(separator: "\n\n\(separator)\n")
        }

        return report
    }
}

