import HTTP
import Telegrammer
import LoggerAPI

class AuthCommandHandler: Handler {

    private let bot: Bot
    private let handler: CommandHandler

    public init(
        bot: Bot,
        name: String = String(describing: CommandHandler.self),
        commands: [String],
        filters: Filters = .all,
        options: CommandHandler.Options = [],
        callback: @escaping HandlerCallback
        ) {
        self.bot = bot
        self.handler = CommandHandler(name: name, commands: commands, filters: filters, options: options, callback: callback)
    }

    // MARK: - Handler

    var name: String {
        return handler.name
    }

    func check(update: Update) -> Bool {
        guard handler.check(update: update) else {
            return false
        }

        guard let message = update.message, let username = message.from?.username else {
            return false
        }

        if Storage.shared.search(nickname: username) {
            do {
                let errorMessage = "Access denied"
                try bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(message.chat.id), text: errorMessage))
            } catch {
                Log.info("error \(error)")
            }

            return true
        } else {
            return false
        }
    }

    public func handle(update: Update, dispatcher: Dispatcher) throws {
        try handler.handle(update: update, dispatcher: dispatcher)
    }
}

