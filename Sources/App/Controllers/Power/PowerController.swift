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

    enum ExeptionError: Error {
        case userNotFound
        case projectNotFound
    }

    // MARK: - CommandsHandler

    var handlers: [Handler] {
        return [CommandHandler(commands: ["/power"], callback: power)]
        //        return [AuthCommandHandler(bot: env.bot, commands: ["/hours"], callback: loadHours)]
    }

    private func power(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        Log.info("Start request power")

        requestUser()
            .thenFuture { (user) -> EventLoopFuture<(User, Project)>? in
                return self.requestProject()
                    .map { (user, $0)}
            }
            .thenFuture { (data) -> EventLoopFuture<(User, Project, [IssueRelationship])>? in
                let (user, project) = data
                let projectId = project.id ?? 0
                let userId = user.id ?? 0

                return self.requestIssueRelationships(projectId: projectId, userId: userId)
                    .map { (issues) -> (User, Project, [IssueRelationship]) in
                        return (user, project, issues)
                    }
            }
            .whenSuccess { (data) in
                let (user, project, issues) = data

                let issuesStrings = issues.compactMap { (issue) -> String? in
                    let trackedTime = issue.trackedHours

                    if trackedTime == 0 {
                        return nil
                    }

                    let id = issue.id ?? 0
                    let subject = issue.rootIssue.issue.subject
                    let time = Float(issue.time).hoursString

                    return "[\(id)] \(subject) {\(issue.childs.count)} \(trackedTime.hoursString)h from \(time)h"
                }

                let text = "\(user.name) \(project.name)\n" + issuesStrings.joined(separator: "\n")

                do {
                    _ = try self.send(chatID: chatID, text: text)
                } catch {
                    Log.error("\(error)")
                }
            }
    }

    private func requestUser() -> Future<User> {
        Log.info("Request user")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, User?)>? in
                let builder = User.query(on: connection)
                    .filter(\User.id, .equal, 285)
                return builder
                    .first()
                    .map { (connection, $0) }
            }
            .map({ (result) -> User? in
                result.0.close()
                return result.1
            })
            .map { (user) -> User in
                guard let user = user else {
                    throw ExeptionError.userNotFound
                }

                return user
            }
    }

    private func requestProject() -> Future<Project> {
        Log.info("Request project")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, Project?)>? in
                let builder = Project.query(on: connection)
                    .filter(\Project.name, .equal, "ЯКИТОРИЯ | IOS")
                return builder
                    .first()
                    .map { (connection, $0) }
            }
            .map({ (result) -> Project? in
                result.0.close()
                return result.1
            })
            .map { (project) -> Project in
                guard let project = project else {
                    throw ExeptionError.projectNotFound
                }

                return project
            }
    }

    private func requestIssueRelationships(projectId: Int, userId: Int) -> Future<[IssueRelationship]> {
        Log.info("Request relationships")

        return requestAllIssues(projectId: projectId)
            .thenFuture { (issues) -> EventLoopFuture<[IssueWithTimeEntries]>? in
                var issuesMap: [Int: IssueWithTimeEntries] = [:]

                for issue in issues {
                    if let id = issue.id {
                        issuesMap[id] = IssueWithTimeEntries(issue: issue)
                    }
                }

                return self.requestTimeEntries(userId: userId, projectId: projectId)
                    .map { (timeEntries) -> ([IssueWithTimeEntries]) in

                        for timeEntiry in timeEntries {
                            issuesMap[timeEntiry.issue_id]?.timeEntries.append(timeEntiry)
                        }

                        Log.info("Add timeEntries to relationships")

                        return Array(issuesMap.values)
                    }
            }
            .thenFuture { (issues) -> EventLoopFuture<[IssueRelationship]>? in
                return self.requestRootIssues(projectId: projectId)
                    .map { (rootIssues) -> ([IssueRelationship]) in
                        var issuesMap: [Int: IssueRelationship] = [:]

                        for issue in rootIssues {
                            if let id = issue.id {
                                issuesMap[id] = issue
                            }
                        }

                        for issue in issues {
                            issuesMap[issue.issue.root_id]?.childs.append(issue)
                        }

                        Log.info("Add childs to issues")

                        return Array(issuesMap.values)
                    }
            }
    }

    /**
     Запрашиваем задачи с внешнеми оценками (запрашиваем все рут задачи)
     */
    private func requestRootIssues(projectId: Int) -> Future<[IssueRelationship]> {
        Log.info("Request root issues")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, [IssueRelationship])>? in
                let builder = Issue.query(on: connection)
                    .filter(\Issue.project_id, .equal, projectId)
                    .join(\CustomValue.customized_id, to: \Issue.id)
                    .filter(\CustomValue.custom_field_id, .equal, 14)
                    .alsoDecode(CustomValue.self)

                return builder
                    .all()
                    .map({ (response) -> ([IssueRelationship]) in
                        Log.info("Map issues to IssueRelationship")

                        return response.compactMap { (item) -> IssueRelationship? in
                            let (issue, customValue) = item

                            if issue.id != issue.root_id {
                                return nil
                            }

                            let time = customValue.value.timeInterval
                            Log.info("Convert \(customValue.value) >> \(time)")

                            let rootIssue = IssueWithTimeEntries(issue: issue)
                            return IssueRelationship(rootIssue: rootIssue, time: time)
                        }
                    })
                    .map { (connection, $0) }
            }
            .map({ (result) -> [IssueRelationship] in
                result.0.close()
                return result.1
            })
    }

    /**
     Запрашиваем все задачи по проекту
     */
    private func requestAllIssues(projectId: Int) -> Future<[Issue]> {
        Log.info("Request all issues")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, [Issue])>? in
                let builder = Issue.query(on: connection)
                    .filter(\Issue.project_id, .equal, projectId)

                return builder
                    .all()
                    .map { (connection, $0) }
            }
            .map({ (result) -> [Issue] in
                Log.info("Complete extract \(result.1.count) issues")

                result.0.close()
                return result.1
            })
    }

    /**
     Запрашиваем все затреканные часы по пользователю внутри проекта
     */
    private func requestTimeEntries(userId: Int, projectId: Int) -> Future<[TimeEntries]> {
        Log.info("Request time entries")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, [TimeEntries])>? in
                let builder = TimeEntries.query(on: connection)
                    .filter(\TimeEntries.user_id, .equal, userId)
                    .filter(\TimeEntries.project_id, .equal, projectId)
                return builder
                    .all()
                    .map { (connection, $0) }
            }
            .map({ (result) -> [TimeEntries] in
                Log.info("Complete extract \(result.1.count) time entries")

                result.0.close()
                return result.1
            })
    }

    private class IssueRelationship {
        let rootIssue: IssueWithTimeEntries
        let time: Double

        var childs: [IssueWithTimeEntries] = []

        var id: Int? {
            return rootIssue.issue.id
        }

        var trackedHours: Float {
            return childs.reduce(0, { $0 + $1.trackedHours })
        }

        init(rootIssue: IssueWithTimeEntries, time: Double) {
            self.rootIssue = rootIssue
            self.time = time
        }
    }

    private class IssueWithTimeEntries {
        let issue: Issue
        var timeEntries: [TimeEntries] = []

        var trackedHours: Float {
            return timeEntries.reduce(0, { $0 + $1.hours })
        }

        init(issue: Issue) {
            self.issue = issue
        }
    }
}

