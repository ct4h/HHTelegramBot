//
//  SubscriptionController.swift
//  App
//
//  Created by basalaev on 17/02/2019.
//

import Foundation
import Telegrammer
import Async
import LoggerAPI

class SubscriptionController: ParentController, CommandsHandler, InlineCommandsHandler {

    // TODO: Переделать на массив
    weak var delegate: InlineCommandsHandler?

    // MARK: - CommandsHandler

    var handlers: [CommandHandler] {
        return [CommandHandler(commands: ["/subscription"], callback: subscription)]
    }

    private func subscription(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id, let delegate = delegate else {
            return
        }

        let query = "\(inlineContext)/\(delegate.inlineContext)"
        try inline(query: query, chatID: chatID, messageID: nil, provider: nil)
    }

    // MARK: - InlineCommandsHandler

    var inlineContext: String {
        return "sub"
    }

    func inline(query: String, chatID: Int64, messageID: Int?, provider: InlineCommandsProvider?) throws {
        guard let delegate = delegate else {
            return
        }

        // TODO: В будущем сделать проверку регуляркой

        Log.info("Subscription handle query \(query) chatID \(chatID) messageID \(String(describing: messageID))")

        try delegate.inline(query: query, chatID: chatID, messageID: messageID, provider: { [weak self] chatID, query in
            guard let self = self else {
                return
            }

            self.saveQuery(chatID: chatID, query: query)
            provider?(chatID, query)
        })
    }

    // MARK: -

    private func saveQuery(chatID: Int64, query: String) {
        let query = query.replacingOccurrences(of: "\(inlineContext)/", with: "")

        print("save query in db \(query)")

        Subscription(chatID: chatID, query: query, period: SubscriptionPeriod.daily.rawValue)
            .save(on: DataBaseConnection(container: env.container))
            .whenSuccess { [weak self] subscription in
                guard let self = self else {
                    return
                }

                let completeText = "Команда: \(query) успешна сохранена"

                do {
                    try self.env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: completeText))
                } catch {
                    print(error.localizedDescription)
                }
        }
    }
}
