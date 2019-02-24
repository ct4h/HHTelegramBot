import Vapor
import Telegrammer
import Jobs

private var botService: RedmineBot?

public func boot(_ app: Application) throws {
    botService = try app.make(RedmineBot.self)
    try start(bot: botService)
}

private func start(bot: RedmineBot?) throws {
    guard let bot = bot else {
        return
    }

    print("Start bot")

    let pollingPromise = try bot.updater?.startLongpolling()
    pollingPromise?.catch({ error in
        print("Longpolling error \(error)")
        do {
            try start(bot: bot)
        } catch {
            print("Fail restart bot")
        }
    })

    // Запускаем выполнение в 11:00
    let startTime = SchedulerTime(hours: 11, minute: 0, dayOffset: nil)
    schedulerDay(start: startTime) {
        bot.executeTimer()
    }
}
