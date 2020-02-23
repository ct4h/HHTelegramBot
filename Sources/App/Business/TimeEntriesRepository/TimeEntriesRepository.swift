import Foundation
import Async
import FluentSQL
import MySQL

final class TimeEntriesRepository: ServiceType {
    private let container: Container

    static func makeService(for container: Container) throws -> TimeEntriesRepository {
        return TimeEntriesRepository(container: container)
    }

    init(container: Container) {
        self.container = container
    }

    func timeEntries(request: TimeEntriesRequest) -> Future<[TimeEntriesResponse]> {
        return container.withPooledConnection(to: .mysql) { request.all(on: $0) }
            .map { (result) -> [TimeEntriesResponse] in
                var data: [Int: [Project: [Issue: [TimeEntries]]]] = [:]

                for ((time, issue), project) in result {
                    var projects = data[time.user_id] ?? [:]
                    var issues = projects[project] ?? [:]
                    var timeEntries = issues[issue] ?? []

                    timeEntries.append(time)
                    
                    issues[issue] = timeEntries
                    projects[project] = issues
                    data[time.user_id] = projects
                }

                return data.map { (userID, projects) -> TimeEntriesResponse in
                    let projectsResponses = projects.map { (project, issues) -> ProjectResponse in
                        let issuesResponses = issues.map { (issue, timeEntries) -> IssueResponse in
                            return IssueResponse(issue: issue, timeEntries: timeEntries)
                        }
                        return ProjectResponse(project: project, issues: issuesResponses)
                    }
                    return TimeEntriesResponse(userID: userID, projects: projectsResponses)
                }
        }
    }
}

// TODO: Добавить сортировки

struct TimeEntriesResponse {
    let userID: Int
    let projects: [ProjectResponse]
}

struct ProjectResponse {
    let project: Project
    let issues: [IssueResponse]

    var totalTime: Float {
        return issues.reduce(into: 0) { $0 = $0 + $1.totalTime }
    }
}

struct IssueResponse {
    let issue: Issue
    let timeEntries: [TimeEntries]

    var totalTime: Float {
        return timeEntries.reduce(into: 0) { $0 = $0 + $1.hours }
    }
}
