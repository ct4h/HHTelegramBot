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

protocol BotHealthLogger: AnyObject {
    func send(error: String) throws
}

class BotHealthController: ParentController, CommandsHandler, BotHealthLogger {
    private let userRepository: UsersRepository
    
    override init(env: BotControllerEnv) {
        if let userRepository: UsersRepository = try? env.container.make() {
            self.userRepository = userRepository
        } else {
            fatalError()
        }

        super.init(env: env)
    }
    
    // MARK: - CommandsHandler
    
    var handlers: [Handler] {
        return [
            CommandHandler(commands: ["/health"], callback: health),
            CommandHandler(commands: ["/users"], callback: users)
        ]
    }
    
    func health(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }
        
        env.container.withPooledConnection(to: .psql) { (connection) -> Future<Subscription> in
            let subscription = Subscription(chatID: chatID, query: "/health")
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
    
    func users(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id, let request = HoursRequest(from: update.message?.text) else {
            return
        }
        
        userRepository
            .users(request: request)
            .whenSuccess { users in
                let text = users
                    .compactMap { user in
                        let fields = user.fields
                            .compactMap { "\($0.name) - \($0.value)" }
                            .joined(separator: "\n")
                        
                        return "\(user.user.name):\n" + fields
                    }
                    .joined(separator: "\n\n")
                
                do {
                    _ = try self.send(chatID: chatID, text: text)
                } catch {
                    Log.error("Error send message \(error.localizedDescription)")
                }
            }
    }
    
    func send(error: String) throws {
        env.container.withPooledConnection(to: .psql) { (connection) -> Future<[Subscription]> in
            return Subscription
                .query(on: connection)
                .filter(\.query, .equal, "/health")
                .all()
        }
        .whenSuccess { (response) in
            do {
                for subscription in response {
                    _ = try self.send(chatID: subscription.chatID, text: error)
                }
            } catch {
                Log.error("Error send message \(error.localizedDescription)")
            }
        }
    }
}
