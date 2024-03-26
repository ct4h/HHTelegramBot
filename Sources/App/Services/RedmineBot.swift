import Foundation
import Telegrammer
import Vapor
import LoggerAPI

final class RedmineBot: ServiceType {

    private let bot: Bot
    private let worker: Worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    private let healthController: BotHealthController
    private let hoursController: HoursController
    private let subscribeController: SubscribeController

    var updater: Updater?
    private var dispatcher: Dispatcher?

    static func makeService(for container: Container) throws -> RedmineBot {
        Log.info("Make Bot service")

        let constants = RuntimeArguments(env: container.environment)
        let settings = Bot.Settings(token: constants.telegram.token, debugMode: true)

        return try RedmineBot(settings: settings, constants: constants, container: container)
    }

    init(settings: Bot.Settings, constants: RuntimeArguments, container: Container) throws {
        bot = try Bot(settings: settings, numThreads: 1)

        let controllerEnv = BotControllerEnv(bot: bot, constants: constants, worker: worker, container: container)

        healthController = BotHealthController(env: controllerEnv)
        
        hoursController = HoursController(env: controllerEnv)
        hoursController.healthLogger = healthController
        
        subscribeController = SubscribeController(env: controllerEnv)
        subscribeController.delegate = self

        try restart()
    }

    func restart() throws {
        // Stop old long polling
        self.updater?.stop()
        
        // Configure dispather
        let dispatcher = Dispatcher(bot: bot, worker: worker)

        healthController.handlers.forEach { dispatcher.add(handler: $0) }
        hoursController.handlers.forEach { dispatcher.add(handler: $0) }
        subscribeController.handlers.forEach { dispatcher.add(handler: $0) }
        
        // Configure Updater
        let updater = Updater(bot: bot, dispatcher: dispatcher, worker: worker)
        
        // Save local var
        self.dispatcher = dispatcher
        self.updater = updater
        
        // Start long polling
        try updater
            .startLongpolling()
            .whenFailure { [weak self] error in
                guard let self = self else {
                    return
                }
                
                do {
                    try self.healthController.send(error: "Longpolling error: \(error)")
                    try self.restart()
                } catch {
                    Log.error("Fail restart bot")
                }
            }
    }
}

extension RedmineBot: SubscribeControllerDelegate {
    func subscribe(updates: [Update]) {
        guard let dispatcher = self.dispatcher else {
            return
        }
        
        Log.info("Bot handle count updates \(updates.count)")

        for update in updates {
            hoursController.handlers.forEach { (handler) in
                if handler.check(update: update) {
                    do {
                        Log.info("Subscribe handle \(update.message?.text ?? "Unknown")")
                        
                        try handler.handle(update: update, dispatcher: dispatcher)
                    } catch {
                        Log.error("Fail handle update \(error)")
                    }
                } else {
                    Log.error("Not checked")
                }
            }
        }
    }
}
