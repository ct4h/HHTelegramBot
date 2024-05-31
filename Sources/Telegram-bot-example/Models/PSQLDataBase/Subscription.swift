import Foundation
import Fluent

final class Subscription: Model {
    init() {}
    
    static var schema: String = "Subscription"

    @ID(custom: .id)
    var id: Int?
        
    @Field(key: "chatID")
    var chatID: Int64
    
    @Field(key: "query")
    var query: String

    init(
        chatID: Int64,
        query: String
    ) {
        self.chatID = chatID
        self.query = query
    }
}
