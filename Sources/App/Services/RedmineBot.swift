import Foundation
import Telegrammer
import Vapor

final class RedmineBot: ServiceType {

    private let bot: Bot
    private let worker: Worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    private let usersControllers: UsersController
    private let hoursControllers: HoursController

    var updater: Updater?
    private var dispatcher: Dispatcher?

    static func makeService(for worker: Container) throws -> RedmineBot {
        let constants = RuntimeArguments(env: worker.environment)
        let settings = Bot.Settings(token: constants.telegram.token, debugMode: true)

        return try RedmineBot(settings: settings, constants: constants)
    }

    init(settings: Bot.Settings, constants: RuntimeArguments) throws {
        bot = try Bot(settings: settings)
        
        usersControllers = UsersController(bot: bot, constants: constants, worker: worker)
        hoursControllers = HoursController(bot: bot, constants: constants, worker: worker)

        let dispatcher = try configureDispatcher()
        self.dispatcher = dispatcher
        self.updater = Updater(bot: bot, dispatcher: dispatcher)
    }

    private func configureDispatcher() throws -> Dispatcher {
        let dispatcher = Dispatcher(bot: bot)

        dispatcher.add(handler: CommandHandler(commands: ["/refreshUsers"], callback: usersControllers.refreshUsers))
        dispatcher.add(handler: CommandHandler(commands: ["/hours"], callback: hoursControllers.loadHours))

        let inlineHandler = CallbackQueryHandler(pattern: "\\w+", callback: hoursControllers.inline)
        dispatcher.add(handler: inlineHandler)

        return dispatcher
    }
}
