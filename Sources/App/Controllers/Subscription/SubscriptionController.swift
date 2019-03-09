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

        // Запускаем планировщик
        schedulerHour { [weak self] (hours) in
            self?.executeSubscriptions(chatID: nil, time: hours)
        }
    }

    func add(child: InlineCommandsHandler) {
        childHandlers.append(child)
    }

    // MARK: - CommandsHandler

    var handlers: [CommandHandler] {
        return [
            CommandHandler(commands: ["/subscription"], callback: subscription),
            CommandHandler(commands: ["/force"], callback: forceExecute),
            CommandHandler(commands: ["/clear"], callback: remove)
        ]
    }

    // MARK: - InlineCommandsHandler

    var inlineContext: String {
        return "sub"
    }

    func inline(query: String, chatID: Int64, provider: InlineCommandsProvider?) throws -> Future<InlineCommandsRequest>? {
        Log.info("Subscription handle query \(query) chatID \(chatID)")

        if let timeRequest = SubscriptionTimeRequest(query: query) {
            saveQuery(chatID: chatID, query: timeRequest.callbackData, time: timeRequest.time)
            provider?(chatID, query)
            return nil
        }

        func check(_ child: InlineCommandsHandler) -> Bool {
            let pattern = "^\(inlineContext)/\(child.inlineContext)(.+)?$"
            Log.info("pattern \(pattern)")
            return query.matchRegexp(pattern: pattern)
        }

        let handler = childHandlers.first { (child) -> Bool in
            return query.matchRegexp(pattern: "^\(inlineContext)/\(child.inlineContext)(.+)?$")
        }

        // Передаем провайдер чтобы не срабатывала обработка команды в дочернем контроллере
        let childPromise = try handler?.inline(query: query, chatID: chatID, provider: { chatID, query in
            provider?(chatID, query)
        })

        if let childPromise = childPromise {
            return childPromise
        } else {
            let factory = SubscriptionTimeRequestFactory(chatID: chatID, callbackData: query)
            let promise = env.worker.eventLoop.newPromise(InlineCommandsRequest.self)
            promise.succeed(result: factory.request)
            return promise.futureResult
        }
    }

    // MARK: -

    private func saveQuery(chatID: Int64, query: String, time: Int8) {
        let query = query.replacingOccurrences(of: "\(inlineContext)/", with: "")

        Log.info("save query in db \(query) on time \(time)")

        let utcTime = time - 3

        env.container.newConnection(to: .psql).whenSuccess { (connection) in
            let subscription = Subscription(chatID: chatID,
                                            query: query,
                                            period: SubscriptionPeriod.daily.rawValue,
                                            time: utcTime)
            let promise = subscription.save(on: connection)

            promise.throwingSuccess({ [weak self] subscription in
                connection.close()

                let completeText = "Команда: \(query) успешно сохранена"
                try self?.env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: completeText))
            })

            promise.throwingFailure({ [weak self] (error) in
                connection.close()

                let errorText = "Не удалось сохранить команду \(query)\nError: \(error)"
                try self?.env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: errorText))
            })
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
        executeSubscriptions(chatID: update.message?.chat.id, time: nil)
    }
}

// MARK: - Remove suscriptions

private extension SubscriptionController {

    func remove(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        env.container.newConnection(to: .psql).whenSuccess { (connection) in
            let promise = Subscription
                .query(on: connection)
                .filter(\.chatID, .equal, chatID)
                .delete()

            promise.throwingSuccess { [weak self] in
                connection.close()

                _ = try self?.send(chatID: chatID, text: "Подписки удалены")
            }

            promise.throwingFailure({ [weak self] (error) in
                connection.close()

                _ = try self?.send(chatID: chatID, text: "Не удалось удалить подписки")
            })
        }
    }
}

// MARK: - Timer

private extension SubscriptionController {

    func executeSubscriptions(chatID: Int64?, time: Int8?) {
        env.container.newConnection(to: .psql).whenSuccess { (connection) in
            var builder: QueryBuilder<PostgreSQLDatabase, Subscription>
            builder = Subscription.query(on: connection)

            if let chatID = chatID {
                builder = builder.filter(\.chatID, .equal, chatID)
            }

            if let time = time {
                builder = builder.filter(\.time, .equal, time)
            }

            let promise = builder.all()

            promise.throwingSuccess { [weak self] (subscriptions) in
                connection.close()

                try self?.execute(subscriptions: subscriptions)
            }

            promise.whenFailure { [weak self] (error) in
                connection.close()

                if let chatID = chatID {
                    let errorText = "Не удалось выполнить запрос к базе"
                    self?.sendIn(chatID: chatID, text: errorText, error: error)
                } else {
                    Log.error("Не удалось извлечь данные \(error)")
                }
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
