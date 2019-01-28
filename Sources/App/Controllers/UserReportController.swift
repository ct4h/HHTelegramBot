//
//  UserReportController.swift
//  App
//
//  Created by basalaev on 26/01/2019.
//

import Foundation
import Telegrammer
import Async

/**
 Контроллер формирует отчет по конкретному человеку
 */
class UserReportController: ParentController {

    private lazy var paginationManager = {
        return PaginationManager<TimeEntriesResponse>(host: constants.redmine.domain,
                                                      port: constants.redmine.port,
                                                      access: constants.redmine.access,
                                                      worker: worker)
    }()

    func userReport(_ update: Update, _ context: BotContext?) throws {
        guard let from = update.message?.from else {
            send(text: "Не удалось определить пользователя", updater: update)
            return
        }

        guard let user = searchUser(nickname: from.username) else {
            send(text: "Не удалось найти пользователя \(String(describing: from.username))", updater: update)
            return
        }

        let date = "2019-01-28"

        paginationManager.all(requestFactory: { (offset, limit) -> ApiTarget in
            return RedmineRequest.timeEntries(userID: user.id, date: date, offset: offset, limit: limit)
        }).whenSuccess { [weak self] timeEntries in
            guard let self = self else {
                return
            }
            
            let report = self.displayData(timeEntries: timeEntries, user: user)
            self.send(text: report, updater: update)
        }
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

    func displayData(timeEntries: [TimeEntries], user: FullUser) -> String {
        var totalHours: Double = 0
        var reportProjects: [Project: [String]] = [:]

        for timeEntry in timeEntries {
            var comments: [String] = []

            if let values = reportProjects[timeEntry.project] {
                comments = values
            }

            totalHours += timeEntry.hours
            comments.append(timeEntry.comments)
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

        var report = "\(user.name): \(totalHours)"
        if !reports.isEmpty {
            report = report + "\n\n" + separator + "\n" + reports.joined(separator: "\n\n\(separator)\n")
        }

        return report
    }
}
