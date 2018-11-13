import Vapor
import Telegrammer

public func boot(_ app: Application) throws {

    let botService = try app.make(RedmineBot.self)

    /// Starting longpolling way to receive bot updates
    /// Or either use webhooks by calling `startWebhooks()` method instead
    _ = try botService.updater?.startLongpolling()

}
