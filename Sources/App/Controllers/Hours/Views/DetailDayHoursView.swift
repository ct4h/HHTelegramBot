//
//  DetailDayHoursView.swift
//  App
//
//  Created by basalaev on 21.01.2020.
//

import Foundation

class DetailDayHoursView: HoursView {

    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        let date = Date().zeroTimeDate?.addingTimeInterval(request.daysOffset * 86_400).stringYYYYMMdd ?? ""

        return responses
            .compactMap { (response) -> String? in
                if response.isOutstaff {
                    return nil
                }

                let totalTime = response.projects.reduce(into: 0) { $0 = $0 + $1.totalTime }

                var components: [String] = []
                components.append("[\(date)]")
                components.append(response.user.name)
                components.append(totalTime.hoursString)

                let userInfo = "*\(components.joined(separator: " "))*"
                let projectsReport = response.projects
                    .map { $0.detailReport }
                    .joined(separator: "\n\n")

                if projectsReport.isEmpty {
                    return userInfo
                } else {
                    return "\(userInfo)\n\n\(projectsReport)"
                }
            }
    }
}

private extension ProjectResponse {

    var detailReport: String {
        let issuesReport = issues
            .compactMap { $0.detailReport }
            .joined(separator: "\n")

        return "*\(project.name) \(totalTime.hoursString):*\n\(issuesReport)"
    }
}

private extension IssueResponse {

    var detailReport: String? {
        guard let issueId = issue.id else {
            return nil
        }

        let timeItems: String

        if timeEntries.isEmpty {
            timeItems = "Без комментариев"
        } else {
            timeItems = timeEntries
                .map({ " • " + $0.comments })
                .joined(separator: "\n")
        }

        let hours = totalTime.hoursString

        return "> [PM-\(issueId)](https://pm.handh.ru/issues/\(issueId)) | \(issue.subject) \(hours):\n\(timeItems)"
    }
}
