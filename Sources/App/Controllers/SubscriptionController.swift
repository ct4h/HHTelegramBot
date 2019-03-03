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

    private var childHandlers: [InlineCommandsHandler] = []

    override init(env: BotControllerEnv) {
        super.init(env: env)

        // Запускаем выполнение в 11:00
        let startTime = SchedulerTime(hours: 11, minute: 0, dayOffset: nil)
        schedulerDay(start: startTime) { [weak self] in
            self?.executeSubscriptions(chatID: nil)
        }
    }

    func add(child: InlineCommandsHandler) {
        childHandlers.append(child)
    }

    // MARK: - CommandsHandler

    var handlers: [CommandHandler] {
        return [
            CommandHandler(commands: ["/subscription"], callback: subscription),
            CommandHandler(commands: ["/force"], callback: forceExecute)
        ]
    }

    // MARK: - InlineCommandsHandler

    var inlineContext: String {
        return "sub"
    }

    func inline(query: String, chatID: Int64, provider: InlineCommandsProvider?) throws -> Future<InlineCommandsRequest>? {
        Log.info("Subscription handle query \(query) chatID \(chatID)")

        func check(_ child: InlineCommandsHandler) -> Bool {
            let pattern = "^\(inlineContext)/\(child.inlineContext)(.+)?$"
            Log.info("pattern \(pattern)")
            return query.matchRegexp(pattern: pattern)
        }

        let handler = childHandlers.first { (child) -> Bool in
            return query.matchRegexp(pattern: "^\(inlineContext)/\(child.inlineContext)(.+)?$")
        }

        return try handler?.inline(query: query, chatID: chatID, provider: { [weak self] chatID, query in
            self?.saveQuery(chatID: chatID, query: query)
            provider?(chatID, query)
        })
    }

    // MARK: -

    private func saveQuery(chatID: Int64, query: String) {
        let query = query.replacingOccurrences(of: "\(inlineContext)/", with: "")

        print("save query in db \(query)")

        Subscription(chatID: chatID, query: query, period: SubscriptionPeriod.daily.rawValue, time: 11)
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

// MARK: - Subscription

private extension SubscriptionController {

    private func subscription(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        let values = childHandlers.map { InlineButtonData(title: $0.inlineContext,
                                                          query: "\(inlineContext)/\($0.inlineContext)") }

        let request = InlineCommandsRequest(context: inlineContext,
                                            title: "Выберите команду",
                                            values: values)

        try sendInlineCommands(chatID: chatID, request: request)
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

        // TODO: Добавить фильтрацию по времени

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
        for subscription in subscriptions {
            for child in childHandlers where child.check(query: subscription.query) {
                let promise = try child.inline(query: subscription.query, chatID: subscription.chatID, provider: nil)
                promise?.whenComplete {
                    Log.info("Успешно отработали подписку \(subscription.query) chatID: \(subscription.chatID)")
                }
            }
        }
    }
}
