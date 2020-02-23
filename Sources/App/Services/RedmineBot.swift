import Foundation
import Telegrammer
import Vapor
import LoggerAPI

final class RedmineBot: ServiceType {

    private let bot: Bot
    private let worker: Worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    private let hoursController: HoursController
    private let subscribeController: SubscribeController

    var updater: Updater?
    private var dispatcher: Dispatcher?

    static func makeService(for worker: Container) throws -> RedmineBot {
        Log.info("Make Bot service")

        let constants = RuntimeArguments(env: worker.environment)
        let settings = Bot.Settings(token: constants.telegram.token, debugMode: true)

        return try RedmineBot(settings: settings, constants: constants, container: worker)
    }

    init(settings: Bot.Settings, constants: RuntimeArguments, container: Container) throws {
        bot = try Bot(settings: settings)

        let controllerEnv = BotControllerEnv(bot: bot, constants: constants, worker: worker, container: container)

        hoursController = HoursController(env: controllerEnv)
        subscribeController = SubscribeController(env: controllerEnv)
        subscribeController.delegate = self

        let dispatcher = try configureDispatcher()
        self.dispatcher = dispatcher
        self.updater = Updater(bot: bot, dispatcher: dispatcher)
    }

    private func configureDispatcher() throws -> Dispatcher {
        Log.info("Make dispatcher")

        let dispatcher = Dispatcher(bot: bot)

        hoursController.handlers.forEach { dispatcher.add(handler: $0) }
        subscribeController.handlers.forEach { dispatcher.add(handler: $0) }

        return dispatcher
    }
}

extension RedmineBot: SubscribeControllerDelegate {
    func subscribe(updates: [Update]) {
        guard let dispatcher = dispatcher else {
            return
        }

        Log.info("bot handle count updates \(updates.count)")

        for update in updates {
            hoursController.handlers.forEach { (handler) in
                if handler.check(update: update) {
                    do {
                        try handler.handle(update: update, dispatcher: dispatcher)
                    } catch {
                        Log.error("\(error)")
                    }
                } else {
                    Log.info("Not checked")
                }
            }
        }
    }
}
