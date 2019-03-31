import Foundation
import Telegrammer
import Vapor

final class RedmineBot: ServiceType {

    private let bot: Bot
    private let worker: Worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    private let usersControllers: UsersController
    private let hoursControllers: HoursController
    private let userReportControllers: UserReportController
    private let subscriptionController: SubscriptionController

    var updater: Updater?
    private var dispatcher: Dispatcher?

    static func makeService(for worker: Container) throws -> RedmineBot {
        let constants = RuntimeArguments(env: worker.environment)
        let settings = Bot.Settings(token: constants.telegram.token, debugMode: true)

        return try RedmineBot(settings: settings, constants: constants, container: worker)
    }

    init(settings: Bot.Settings, constants: RuntimeArguments, container: Container) throws {
        bot = try Bot(settings: settings)

        let controllerEnv = BotControllerEnv(bot: bot, constants: constants, worker: worker, container: container)

        usersControllers = UsersController(env: controllerEnv)

        hoursControllers = HoursController(env: controllerEnv)

        userReportControllers = UserReportController(env: controllerEnv)
        userReportControllers.delegate = hoursControllers

        subscriptionController = SubscriptionController(env: controllerEnv)
        subscriptionController.add(child: hoursControllers)
        subscriptionController.add(child: userReportControllers)

        let dispatcher = try configureDispatcher()
        self.dispatcher = dispatcher
        self.updater = Updater(bot: bot, dispatcher: dispatcher)
    }

    private func configureDispatcher() throws -> Dispatcher {
        let dispatcher = Dispatcher(bot: bot)

        commandHandlers
            .reduce([]) { (result, handler) -> [Handler] in
                var result = result
                result.append(contentsOf: handler.handlers)
                return result
            }
            .forEach({ dispatcher.add(handler: $0) })

        inlineCommmandHandlers.forEach({ dispatcher.add(handler: $0.callbackHanler) })

        return dispatcher
    }

    // MARK: - Helpers

    private var commandHandlers: [CommandsHandler] {
        return [usersControllers, hoursControllers, userReportControllers, subscriptionController]
    }

    private var inlineCommmandHandlers: [InlineCommandsHandler] {
        return [hoursControllers, subscriptionController]
    }
}
