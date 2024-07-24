//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 30.05.2024.
//

import Foundation
import Vapor
import SwiftTelegramSdk
import Fluent
import Algorithms

final class SubscriptionsHandles {
    static func addHandlers(bot: TGBot) async {
        await subscribe(bot: bot)
        await deleteChatSubscriptions(bot: bot)
        await deleteSubscription(bot: bot)
        await force(bot: bot)
        await chatSubscriptions(bot: bot)
        await allSubscriptions(bot: bot)
    }
    
    private static func subscribe(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/subscribe"]) { update in
            guard let message = update.message, let query = message.text else {
                return
            }
            
            let subscription = Subscription(chatID: message.chat.id, query: query)
            try await subscription.create(on: app.db(.psql))
            try await bot.sendMessage(params: .init(chatId: .chat(message.chat.id), text: "Команда успешно сохранена"))
        })
    }
    
    private static func deleteChatSubscriptions(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/deleteChatSubscriptions"]) { update in
            guard let message = update.message else {
                return
            }
            
            try await Subscription.query(on: app.db(.psql))
                .filter(\.$chatID == message.chat.id)
                .delete()

            try await bot.sendMessage(params: .init(chatId: .chat(message.chat.id), text: "Подписки удалены"))
        })
    }
    
    private static func deleteSubscription(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/deleteSubscription"]) { update in
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
    
    private static func force(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/force"]) { update in
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
            
            bot.dispatcher.process(updates)
        })
    }
    
    private static func chatSubscriptions(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/chatSubscriptions"]) { update in
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
    
    private static func allSubscriptions(bot: TGBot) async {
        await bot.dispatcher.add(TGCommandHandler(commands: ["/allSubscriptions"]) { update in
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
