import Vapor
import Telegrammer
import LoggerAPI

private var botService: RedmineBot?

public func boot(_ app: Application) throws {
    botService = try app.make(RedmineBot.self)
}
