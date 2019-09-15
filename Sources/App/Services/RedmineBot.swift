import Foundation
import Telegrammer
import Vapor
import LoggerAPI

final class RedmineBot: ServiceType {

    private let bot: Bot
    private let worker: Worker = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    private let hoursController: HoursController
    private let userReportController: UserReportController
    private let weaklyHoursController: WeaklyHoursController
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

        hoursController = HoursController(env: controllerEnv)

        userReportController = UserReportController(env: controllerEnv)
        userReportController.delegate = hoursController

        weaklyHoursController = WeaklyHoursController(env: controllerEnv)
        weaklyHoursController.delegate = hoursController

        subscriptionController = SubscriptionController(env: controllerEnv)
        subscriptionController.add(child: hoursController)
        subscriptionController.add(child: userReportController)

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
        return [hoursController, userReportController, weaklyHoursController, subscriptionController]
    }

    private var inlineCommmandHandlers: [InlineCommandsHandler] {
        return [hoursController, weaklyHoursController, subscriptionController]
    }
}
