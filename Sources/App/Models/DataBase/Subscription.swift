import Foundation
import FluentPostgreSQL
import Telegrammer

final class Subscription: PostgreSQLModel {
    var id: Int?
    var chatID: Int64
    var query: String
    var period: String // См. SubscriptionPeriod

    init(chatID: Int64, query: String, period: String) {
        self.chatID = chatID
        self.query = query
        self.period = period
    }
}

extension Subscription: Migration { }
