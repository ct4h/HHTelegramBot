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
import FluentPostgreSQL

class SubscriptionController: ParentController, CommandsHandler, InlineCommandsHandler {

    // TODO: Переделать на массив
    weak var delegate: InlineCommandsHandler?

    override init(env: BotControllerEnv) {
        super.init(env: env)

        // Запускаем выполнение в 11:00
        let startTime = SchedulerTime(hours: 11, minute: 0, dayOffset: nil)
        schedulerDay(start: startTime) { [weak self] in
            self?.executeSubscriptions(chatID: nil)
        }
    }

    // MARK: - CommandsHandler

    var handlers: [CommandHandler] {
        return [
            CommandHandler(commands: ["/subscription"], callback: subscription),
            CommandHandler(commands: ["/force"], callback: forceExecute)
        ]
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

// MARK: - Force execute subscriptions

private extension SubscriptionController {

    func forceExecute(_ update: Update, _ context: BotContext?) throws {
        executeSubscriptions(chatID: update.message?.chat.id)
    }
}

// MARK: - Timer

private extension SubscriptionController {

    func executeSubscriptions(chatID: Int64?) {
        let connection = DataBaseConnection(container: env.container)
        let requestPromise: Future<[Subscription]>

        if let chatID = chatID {
            requestPromise = Subscription
                .query(on: connection)
                .filter(\.chatID, .equal, chatID)
                .all()

            requestPromise.whenFailure { [weak self] (error) in
                let errorText = "Не удалось выполнить запрос к базе"
                self?.sendIn(chatID: chatID, text: errorText, error: error)
            }
        } else {
            requestPromise = Subscription
                .query(on: connection)
                .all()
        }

        requestPromise.whenSuccess { [weak self] subscriptions in
            do {
                try self?.execute(subscriptions: subscriptions)
            } catch {
                Log.error(error.localizedDescription)
            }
        }
    }

    func execute(subscriptions: [Subscription]) throws {
        guard let delegate = delegate else {
            return
        }

        for subscription in subscriptions {
            for inlineHandler in [delegate] where inlineHandler.check(query: subscription.query) {
                try inlineHandler.inline(query: subscription.query,
                                         chatID: subscription.chatID,
                                         messageID: nil,
                                         provider: nil)
            }
        }
    }
}
