import Foundation
import FluentMySQL

final class TimeEntries: MySQLModel {

    static let entity = "time_entries"
    
    var id: Int?
    var project_id: Int
    var user_id: Int
    var issue_id: Int
    var hours: Float
    var comments: String
    var activity_id: Int
    var spent_on: Date
    var tyear: Int
    var tmonth: Int
    var created_on: Date
    var updated_on: Date

    init(id: Int,
         project_id: Int,
         user_id: Int,
         issue_id: Int,
         hours: Float,
         comments: String,
         activity_id: Int,
         spent_on: Date,
         tyear: Int,
         tmonth: Int,
         created_on: Date,
         updated_on: Date) {

        self.id = id
        self.project_id = project_id
        self.user_id = user_id
        self.issue_id = issue_id
        self.hours = hours
        self.comments = comments
        self.activity_id = activity_id
        self.spent_on = spent_on
        self.tyear = tyear
        self.tmonth = tmonth
        self.created_on = created_on
        self.updated_on = updated_on
    }
}
