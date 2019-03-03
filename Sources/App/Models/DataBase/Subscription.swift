import Foundation
import FluentPostgreSQL
import Telegrammer
import LoggerAPI

final class Subscription: PostgreSQLModel {

    var id: Int?
    var chatID: Int64
    var query: String
    var period: String // См. SubscriptionPeriod
    var time: Int8

    init(chatID: Int64, query: String, period: String, time: Int8) {
        self.chatID = chatID
        self.query = query
        self.period = period
        self.time = time
    }
}

extension Subscription: Migration {}

struct AddSubscriptionTime: PostgreSQLMigration {

    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return Database.update(Subscription.self, on: conn) { builder in
            let defaultValue = PostgreSQLColumnConstraint.default(.literal(11), identifier: nil)
            builder.field(for: \.time, type: .int8, defaultValue)
        }
    }

    static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
        return Database.update(Subscription.self, on: conn) { builder in
            builder.deleteField(for: \.time)
        }
    }
}
