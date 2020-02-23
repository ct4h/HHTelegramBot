import Foundation
import FluentPostgreSQL
import Telegrammer
import LoggerAPI

final class Subscription: PostgreSQLModel {

    var id: Int?
    var chatID: Int64
    var query: String

    init(chatID: Int64, query: String) {
        self.chatID = chatID
        self.query = query
    }
}

extension Subscription: Migration {}

struct DeletePeriodTimeMigration: PostgreSQLMigration {

    static func prepare(on conn: PostgreSQLConnection) -> Future<Void> {
        return Database.update(Subscription.self, on: conn) { builder in
            builder.deleteField(PostgreSQLColumnIdentifier.column(nil, PostgreSQLIdentifier("period")))
            builder.deleteField(PostgreSQLColumnIdentifier.column(nil, PostgreSQLIdentifier("time")))
        }
    }

    static func revert(on conn: PostgreSQLConnection) -> Future<Void> {
        return Database.update(Subscription.self, on: conn) { builder in
        }
    }
}
