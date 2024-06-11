//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 30.05.2024.
//

import Foundation
import Vapor
import TelegramVaporBot
import Fluent
import Algorithms

final class SubscriptionsHandles {
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await subscribe(app: app, connection: connection)
        await deleteChatSubscriptions(app: app, connection: connection)
        await deleteSubscription(app: app, connection: connection)
        await force(app: app, connection: connection)
        await chatSubscriptions(app: app, connection: connection)
        await allSubscriptions(app: app, connection: connection)
    }
    
    private static func subscribe(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/subscribe"]) { update, bot in
            guard let message = update.message, let query = message.text else {
                return
            }
            
            let subscription = Subscription(chatID: message.chat.id, query: query)
            try await subscription.create(on: app.db(.psql))
            try await bot.sendMessage(params: .init(chatId: .chat(message.chat.id), text: "Команда успешно сохранена"))
        })
    }
    
    private static func deleteChatSubscriptions(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/deleteChatSubscriptions"]) { update, bot in
            guard let message = update.message else {
                return
            }
            
            try await Subscription.query(on: app.db(.psql))
                .filter(\.$chatID == message.chat.id)
                .delete()

            try await bot.sendMessage(params: .init(chatId: .chat(message.chat.id), text: "Подписки удалены"))
        })
    }
    
    private static func deleteSubscription(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/deleteSubscription"]) { update, bot in
            guard 
                let message = update.message,
                let text = message.text,
                let substring = text.split(separator: " ").last,
                let id = Int(substring)
            else {
                return
            }
            
            try await Subscription.query(on: app.db(.psql))
                .filter(\.$id == id)
                .delete()

            try await bot.sendMessage(params: .init(chatId: .chat(message.chat.id), text: "Подписка удалена"))
        })
    }
    
    private static func force(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/force"]) { update, bot in
            guard let message = update.message else {
                return
            }
            
            let updates = try await Subscription
                .query(on: app.db(.psql))
                .filter(\.$chatID == message.chat.id)
                .all()
                .compactMap {
                    SubscribeRequest(chatID: $0.chatID, query: $0.query)
                }
                .map { request in
                    let chat = TGChat(id: request.chatID, type: .undefined)
                    let entity = TGMessageEntity(type: .botCommand, offset: 0, length: request.command.count + 1)
                    let message = TGMessage(messageId: 0, date: 0, chat: chat, text: request.query, entities: [entity])
                    
                    return TGUpdate(updateId: 0, message: message)
                }
            
            try await TGBOT.connection.dispatcher.process(updates)
        })
    }
    
    private static func chatSubscriptions(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/chatSubscriptions"]) { update, bot in
            guard let message = update.message else {
                return
            }
            
            let text = try await Subscription
                .query(on: app.db(.psql))
                .filter(\.$chatID == message.chat.id)
                .all()
                .map { "\($0.id ?? -1) \($0.chatID) \($0.query)" }
                .joined(separator: "\n")
            
            try await bot.sendMessage(params: .init(chatId: .chat(message.chat.id), text: text))
        })
    }
    
    private static func allSubscriptions(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/allSubscriptions"]) { update, bot in
            guard let message = update.message else {
                return
            }
            
            let subscriptions = try await Subscription
                .query(on: app.db(.psql))
                .sort(\.$id)
                .all()
                .map { "\($0.id ?? -1) \($0.chatID) \($0.query)" }
                .chunks(ofCount: 10)
                
            // TODO: Добавить обертку над foreach для try async
            for chunck in subscriptions {
                let text: String = chunck.joined(separator: "\n")
                try await bot.sendMessage(params: .init(chatId: .chat(message.chat.id), text: text))
            }
        })
    }
}
