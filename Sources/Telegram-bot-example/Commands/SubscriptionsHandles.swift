//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 30.05.2024.
//

import Foundation
import Vapor
import TelegramVaporBot

final class SubscriptionsHandles {
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await allSubscriptions(app: app, connection: connection)
    }
    
    static func allSubscriptions(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        await connection.dispatcher.add(TGCommandHandler(commands: ["/allsubscriptions"]) { update, bot in
            guard let message = update.message else {
                return
            }
            
            let text = try await Subscription
                .query(on: app.db(.psql))
                .all()
                .map { "\($0.id ?? -1) \($0.chatID) \($0.query)" }
                .joined(separator: "\n")
            
            try await bot.sendMessage(params: .init(chatId: .chat(message.chat.id), text: text))
        })
    }
}
