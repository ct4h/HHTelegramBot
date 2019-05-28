import Vapor
import Telegrammer
import LoggerAPI

private var botService: RedmineBot?

public func boot(_ app: Application) throws {
    botService = try app.make(RedmineBot.self)
    try start(bot: botService)
}

private func start(bot: RedmineBot?) throws {
    guard let bot = bot else {
        return
    }

    let pollingPromise = try bot.updater?.startLongpolling()
    pollingPromise?.catch({ error in
        Log.error("Longpolling error \(error)")

        do {
            Log.info("Restart bot")
            try start(bot: bot)
        } catch {
            Log.error("Fail restart bot")
        }
    })
}
