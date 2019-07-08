//
//  Issue.swift
//  App
//
//  Created by basalaev on 21/04/2019.
//

import Foundation
import FluentMySQL

final class Issue: MySQLModel, Hashable {

    static let entity = "issues"

    var id: Int?
    var tracker_id: Int
    var project_id: Int
    var subject: String
    var root_id: Int
    var status_id: Int

    init(
        id: Int,
        tracker_id: Int,
        customized_id: Int,
        project_id: Int,
        subject: String,
        root_id: Int,
        status_id: Int
        ) {

        self.id = id
        self.tracker_id = tracker_id
        self.project_id = project_id
        self.subject = subject
        self.root_id = root_id
        self.status_id = status_id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Issue, rhs: Issue) -> Bool {
        return lhs.id == rhs.id
    }
}
