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
        guard let message = update.message else {
            return
        }

        let parameters = message.text?.replacingOccurrences(of: "/power ", with: "power?").urlParameters
        Log.info("Original text \(String(describing: message.text)) >> parameters \(String(describing: parameters))")

        guard let userId = Int(parameters?["user"] ?? ""), let projectName = parameters?["project"] else {
            return
        }

        let debugMode = parameters?["debugMode"] != nil

        Log.info("Start request power")

        requestUser(id: userId)
            .thenFuture { (user) -> EventLoopFuture<(User, Project)>? in
                return self.requestProject(name: projectName)
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

                var allTrackedTime: Float = 0
                var allFutureTime: Float = 0

                issues.forEach({ (issue) in
                    guard issue.closed else {
                        return
                    }

                    let trackedTime = issue.userTrackedHours

                    guard trackedTime != 0 else {
                        return
                    }


                    allTrackedTime += trackedTime
                    allFutureTime += trackedTime * Float(issue.time) / issue.allTrackerHours
                })

                /*
                let sortedIssues = issues.sorted(by: { (lhs, rhs) -> Bool in
                    return (lhs.id ?? 0) < (rhs.id ?? 0)
                })

                var powers: [Float] = []

                let issuesStrings = sortedIssues.compactMap { (issue) -> String? in
                    let trackedTime = issue.userTrackedHours

                    if trackedTime == 0 {
                        return nil
                    }

                    let issueId = issue.id ?? 0
                    let issueText = "[PM-\(issueId)](https://pm.handh.ru/issues/\(issueId))"

                    var subject = issue.rootIssue.issue.subject

                    let subjectMaxLenght = 25
                    if subject.count > subjectMaxLenght {
                        subject = subject.prefix(subjectMaxLenght) + "..."
                    }

                    let futureTime = Float(issue.time)
                    let totalTime = issue.allTrackerHours

                    let power = ((totalTime - futureTime) * trackedTime / (totalTime * futureTime)) + 1
                    powers.append(power)

                    if !debugMode {
                        return nil
                    }

                    let futureTimeString = "Оценка: \(futureTime.hoursString)h"
                    let totalTimeString = "Всего: \(totalTime.hoursString)h"
                    let userTimeString = "Затрекал: \(trackedTime.hoursString)h"
                    let powerString = "Мощность: \(power)"

                    return [
                        " • \(issueText) \(subject):",
                        futureTimeString,
                        totalTimeString,
                        userTimeString,
                        powerString
                    ].joined(separator: "\n")
                }

                let avgPower = powers.reduce(0, +) / Float(powers.count)
 */

                let avgPower = allTrackedTime / allFutureTime
                let text = "*\(user.name) \(project.name) \(avgPower)*\n\n" + "Затрекал \(allTrackedTime) | Проданно \(allFutureTime)"

                do {
                    _ = try self.send(chatID: message.chat.id, text: text)
                } catch {
                    Log.error("\(error)")
                }
            }
    }

    private func requestUser(id: Int) -> Future<User> {
        Log.info("Request user")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, User?)>? in
                let builder = User.query(on: connection)
                    .filter(\User.id, .equal, id)
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

    private func requestProject(name: String) -> Future<Project> {
        Log.info("Request project")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, Project?)>? in
                let builder = Project.query(on: connection)
                    .filter(\Project.name, .equal, name)
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

                return self.requestUserTimeEntries(userId: userId, projectId: projectId)
                    .map { (timeEntries) -> ([IssueWithTimeEntries]) in

                        for timeEntiry in timeEntries {
                            issuesMap[timeEntiry.issue_id]?.userTimeEntries.append(timeEntiry)
                        }

                        Log.info("Add user timeEntries to relationships")

                        return Array(issuesMap.values)
                    }
            }
            .thenFuture { (issues) -> EventLoopFuture<[IssueWithTimeEntries]>? in
                var issuesMap: [Int: IssueWithTimeEntries] = [:]

                for issue in issues {
                    if let id = issue.issue.id {
                        issuesMap[id] = issue
                    }
                }

                return self.requestAllTimeEntries(projectId: projectId)
                    .map { (timeEntries) -> ([IssueWithTimeEntries]) in

                        for timeEntiry in timeEntries {
                            issuesMap[timeEntiry.issue_id]?.allTimeEntries.append(timeEntiry)
                        }

                        Log.info("Add all timeEntries to relationships")

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
    private func requestUserTimeEntries(userId: Int, projectId: Int) -> Future<[TimeEntries]> {
        Log.info("Request user time entries")

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

    /**
     Запрашиваем все затреканные часы внутри проекта
     */
    private func requestAllTimeEntries(projectId: Int) -> Future<[TimeEntries]> {
        Log.info("Request all time entries")

        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, [TimeEntries])>? in
                let builder = TimeEntries.query(on: connection)
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

        var closed: Bool {
            return rootIssue.closed
        }

        var userTrackedHours: Float {
            return childs.reduce(0, { $0 + $1.userTrackedHours })
        }

        var allTrackerHours: Float {
            return childs.reduce(0, { $0 + $1.allTrackerHours })
        }

        init(rootIssue: IssueWithTimeEntries, time: Double) {
            self.rootIssue = rootIssue
            self.time = time
        }
    }

    private class IssueWithTimeEntries {
        let issue: Issue
        var userTimeEntries: [TimeEntries] = []
        var allTimeEntries: [TimeEntries] = []

        var userTrackedHours: Float {
            return userTimeEntries.reduce(0, { $0 + $1.hours })
        }

        var allTrackerHours: Float {
            return allTimeEntries.reduce(0, { $0 + $1.hours })
        }

        var closed: Bool {
            return issue.status_id == 5
        }

        init(issue: Issue) {
            self.issue = issue
        }
    }
}

