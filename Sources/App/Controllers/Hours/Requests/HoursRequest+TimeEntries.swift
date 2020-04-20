//
//  HoursRequest+TimeEntries.swift
//  App
//
//  Created by basalaev on 20.01.2020.
//

import Foundation
import Async
import FluentSQL
import MySQL
import LoggerAPI

// TODO: Добавить поддержку массивов

extension HoursRequest: TimeEntriesRequest {

    func all(on connection: MySQLDatabase.Connection) -> Future<[TimeEntriesResult]> {
        var builder = TimeEntries.query(on: connection)
            .join(\User.id, to: \TimeEntries.user_id)
            .join(\Issue.id, to: \TimeEntries.issue_id)
            .join(\Project.id, to: \TimeEntries.project_id)
            .filter(\User.status, .equal, 1)
            .alsoDecode(Issue.self)
            .alsoDecode(Project.self)

        if let customField = customFields.first, let customValue = customValues.first {
            builder = builder
                .join(\CustomValue.customized_id, to: \User.id)
                .join(\CustomField.id, to: \CustomValue.custom_field_id)
                .filter(\CustomField.name, .equal, customField)
                .filter(\CustomValue.value, .equal, customValue)
        }

        if let department = departments.first {
            builder = builder
                .join(\PeopleInformation.user_id, to: \User.id)
                .join(\Department.id, to: \PeopleInformation.department_id)
                .filter(\Department.name, .equal, department)
        }

        if let date = Date().zeroTimeDate {
            let daySeconds: TimeInterval = 86_400
            switch period {
            case .day:
                let reportDate = date.addingTimeInterval(daysOffset * daySeconds)
                let reportDateString = DateFormatter.yyyyMMdd.string(from: reportDate)

                Log.info("like \(reportDateString)")

                builder = builder
                    .filter(MySQLDatabase.queryField(.keyPath(\TimeEntries.spent_on)), .like, reportDateString)
            case .weak:
                let fromDate = date.addingTimeInterval((-6 + daysOffset) * daySeconds)
                let toDate = date.addingTimeInterval(daysOffset * daySeconds)

                builder = builder
                    .filter(\TimeEntries.spent_on, .greaterThanOrEqual, fromDate)
                    .filter(\TimeEntries.spent_on, .lessThanOrEqual, toDate)
            }
        }

        return builder.all()
    }
}
