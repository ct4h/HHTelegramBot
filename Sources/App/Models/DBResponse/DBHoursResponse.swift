//
//  DBHoursResponse.swift
//  App
//
//  Created by basalaev on 26/05/2019.
//

import Foundation

typealias DBHoursResponse = [User: [Project: [Issue: [TimeEntries]]]]

extension Array where Element == (((User, TimeEntries), Issue), Project) {

    var hoursResponse: DBHoursResponse {
        var mappedData: [User: [Project: [Issue: [TimeEntries]]]] = [:]

        for (((user, timeEntry), issue), project) in self {
            var userProjects: [Project: [Issue: [TimeEntries]]] = [:]

            if let buffer = mappedData[user] {
                userProjects = buffer
            }

            var projectIssues: [Issue: [TimeEntries]] = [:]

            if let buffer = userProjects[project] {
                projectIssues = buffer
            }

            var issueTimeEntries: [TimeEntries] = []

            if let buffer = projectIssues[issue] {
                issueTimeEntries = buffer
            }

            issueTimeEntries.append(timeEntry)
            projectIssues[issue] = issueTimeEntries
            userProjects[project] = projectIssues
            mappedData[user] = userProjects
        }

        return mappedData
    }
}