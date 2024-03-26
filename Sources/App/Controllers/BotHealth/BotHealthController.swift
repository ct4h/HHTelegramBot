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
    
    // MARK: - CommandsHandler
    
    var handlers: [Handler] {
        return [
            CommandHandler(commands: ["/health"], callback: health)
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
