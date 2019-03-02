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
        subscriptionController = SubscriptionController(env: controllerEnv)
        subscriptionController.delegate = hoursControllers

        let dispatcher = try configureDispatcher()
        self.dispatcher = dispatcher
        self.updater = Updater(bot: bot, dispatcher: dispatcher)
    }

    private func configureDispatcher() throws -> Dispatcher {
        let dispatcher = Dispatcher(bot: bot)

        dispatcher.add(handler: CommandHandler(commands: ["/refreshUsers"], callback: usersControllers.refreshUsers))
        dispatcher.add(handler: CommandHandler(commands: ["/hours"], callback: hoursControllers.loadHours))
        dispatcher.add(handler: CommandHandler(commands: ["/dayReport"], callback: userReportControllers.userReport))
        dispatcher.add(handler: CommandHandler(commands: ["/subscription"], callback: subscriptionController.subscription))
        dispatcher.add(handler: CommandHandler(commands: ["/force"], callback: force))

        inlineHandlers.forEach({ dispatcher.add(handler: $0.callbackHanler) })

        return dispatcher
    }

    // TODO: Перенести обработку таймера внутрь subscriptionController

    func executeTimer() {
        Subscription
            .query(on: DataBaseConnection(container: subscriptionController.env.container))
            .all()
            .whenSuccess { [weak self] subscriptions in
                guard let self = self else {
                    return
                }

                do {
                    try self.execute(subscriptions: subscriptions)
                } catch {
                    print(error.localizedDescription)
                }
        }
    }

    func force(_ update: Update, _ context: BotContext?) throws {
        executeTimer()
    }

    private func execute(subscriptions: [Subscription]) throws {
        for subscription in subscriptions {
            for inlineHandler in inlineHandlers where inlineHandler.check(query: subscription.query) {
                try inlineHandler.inline(query: subscription.query,
                                         chatID: subscription.chatID,
                                         messageID: nil,
                                         provider: nil)
            }
        }
    }

    // MARK: - Helpers

    private var inlineHandlers: [InlineCommandsHandler] {
        return [hoursControllers, subscriptionController]
    }
}
