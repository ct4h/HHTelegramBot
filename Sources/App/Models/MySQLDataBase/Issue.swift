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

    init(id: Int, tracker_id: Int, customized_id: Int, project_id: Int, subject: String) {
        self.id = id
        self.tracker_id = tracker_id
        self.project_id = project_id
        self.subject = subject
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Issue, rhs: Issue) -> Bool {
        return lhs.id == rhs.id
    }
}
