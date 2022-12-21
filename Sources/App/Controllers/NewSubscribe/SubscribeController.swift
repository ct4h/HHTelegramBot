//
//  SubscribeController.swift
//  App
//
//  Created by basalaev on 21.01.2020.
//

import Foundation
import Telegrammer
import Async
import LoggerAPI
import FluentSQL
import FluentPostgreSQL

protocol SubscribeControllerDelegate: AnyObject {
    func subscribe(updates: [Update])
}

class SubscribeController: ParentController, CommandsHandler {
    private let scheduler = SubscribeScheduler()

    weak var delegate: SubscribeControllerDelegate?

    override init(env: BotControllerEnv) {
        super.init(env: env)

        scheduler.schedulerHour { [weak self] (time, day) in
            self?.execute(chatID: nil, time: time, day: day)
        }
    }

    // MARK: - CommandsHandler

    var handlers: [Handler] {
        return [
            CommandHandler(commands: ["/subscribe"], callback: subscribe),
            CommandHandler(commands: ["/clear"], callback: remove),
            CommandHandler(commands: ["/force"], callback: force),
            CommandHandler(commands: ["/subscriptions"], callback: subscriptions),
            CommandHandler(commands: ["/check"], callback: check)
        ]
    }

    func subscribe(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id, let text = update.message?.text else {
            return
        }

        _ = try? self.send(chatID: chatID, text: "subscribe begin")
        
        env.container.withPooledConnection(to: .psql) { (connection) -> Future<Subscription> in
            let subscription = Subscription(chatID: chatID, query: text)
            return subscription.save(on: connection)
        }
        .thenIfErrorThrowing { error in
            _ = try? self.send(chatID: chatID, text: "subscribe \(error)")
            return Subscription(chatID: chatID, query: "")
        }
        .whenSuccess { subscription in
            do {
                if !subscription.query.isEmpty {
                    _ = try self.send(chatID: chatID, text: "Команда успешно сохранена")
                }
                
                Log.info("Complete send message")
            } catch {
                Log.error("Error send message \(error.localizedDescription)")
            }
        }
    }

    func force(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        Log.info("Hours \(String(describing: scheduler.currentHours)) day \(String(describing: scheduler.currentDay))")
        execute(chatID: chatID, time: nil, day: nil)
    }

    func remove(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        env.container.withPooledConnection(to: .psql) { (connection) -> Future<Void> in
            return Subscription
                .query(on: connection)
                .filter(\.chatID, .equal, chatID)
                .delete()
        }
        .whenSuccess { (_) in
            do {
                _ = try self.send(chatID: chatID, text: "Подписки удалены")
            } catch {
                Log.error("Error send message \(error.localizedDescription)")
            }
        }
    }

    func subscriptions(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        env.container.withPooledConnection(to: .psql) { (connection) -> Future<[Subscription]> in
            return Subscription
                .query(on: connection)
                .filter(\.chatID, .equal, chatID)
                .all()
        }
        .map({ (subscriptions) -> String in
            subscriptions
                .map { $0.query }
                .joined(separator: "\n")
        })
        .whenSuccess { (response) in
            do {
                _ = try self.send(chatID: chatID, text: response)
            } catch {
                Log.error("Error send message \(error.localizedDescription)")
            }
        }
    }

    func check(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        guard let calendar = NSCalendar(identifier: .gregorian) else {
            return
        }

        let days: [(SubscribeRequest.Days, String)] = [
            (.sunday, "Воскресенье"),
            (.monday, "Понедельник"),
            (.tuesday, "Вторник"),
            (.wednesday, "Среда"),
            (.thursday, "Четверг"),
            (.friday, "Пятница"),
            (.saturday, "Суббота"),
        ]

        let daySeconds = 86_400

        env.container.withPooledConnection(to: .psql) { (connection) -> Future<[Subscription]> in
            return Subscription
                .query(on: connection)
                .all()
        }
        .map { (subscriptions) -> [SubscribeRequest] in
            return subscriptions
                .compactMap { (subscription) -> SubscribeRequest? in
                    SubscribeRequest(chatID: subscription.chatID, query: subscription.query)
            }
        }
        .whenSuccess { (requests) in
            do {
                for i in 0..<7 {
                    var dayResults: [String] = []

                    let date = Date().addingTimeInterval(TimeInterval(daySeconds * i))
                    dayResults.append("Weekday: \(String(describing: calendar.components([.weekday], from: date).weekday))")

                    if let weekday = calendar.components([.weekday], from: date).weekday, let (day, desc) = days[safe: weekday - 1] {
                        dayResults.append("\(date.stringYYYYMMdd) \(desc):")

                        requests.forEach { (request) in
                            if request.days.contains(day) {
                                dayResults.append(request.query)
                            }
                        }
                    }

                    _ = try self.send(chatID: chatID, text: dayResults.joined(separator: "\n"))
                }
            } catch {
                Log.error("Error send message \(error.localizedDescription)")
            }
        }
    }

    private func execute(chatID: Int64?, time: Int?, day: SubscribeRequest.Days?) {
        env.container.withPooledConnection(to: .psql) { (connection) -> Future<[Subscription]> in
            Log.info("Extract subscribes")

            var builder = Subscription.query(on: connection)

            if let chatID = chatID {
                builder = builder.filter(\.chatID, .equal, chatID)
            }

            return builder.all()
        }
        .map { (subscriptions) -> [SubscribeRequest] in
            Log.info("Convert subscriptions to requests \(subscriptions.count)")
            return subscriptions
                .compactMap { (subscription) -> SubscribeRequest? in
                    SubscribeRequest(chatID: subscription.chatID, query: subscription.query)
                }
                .filter { (request) -> Bool in
                    if let time = time, let day = day {
                        return request.time == time && request.days.contains(day)
                    } else {
                        return true
                    }
                }
        }
        .map { (requests) -> [Update] in
            Log.info("Convert to Update requests \(requests.count)")

            return requests.map { (request) -> Update in
                let chat = Chat(id: request.chatID, type: .undefined)
                let entity = MessageEntity(type: .botCommand, offset: 0, length: request.command.count + 1)
                let message = Message(messageId: 0, date: 0, chat: chat, text: request.query, entities: [entity])
                return Update(updateId: 0, message: message)
            }
        }
        .whenSuccess { [weak self] (updates) in
            self?.delegate?.subscribe(updates: updates)
        }
    }
}
