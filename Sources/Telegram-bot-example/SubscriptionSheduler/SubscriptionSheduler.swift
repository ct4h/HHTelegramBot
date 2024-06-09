//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 30.05.2024.
//

import Vapor
import Queues
import Fluent
import TelegramVaporBot

struct SubscriptionSheduler: AsyncScheduledJob {
    func run(context: QueueContext) async throws {
        guard 
            let calendar = NSCalendar(identifier: .gregorian),
            let timeZone = TimeZone(secondsFromGMT: 10_800)
        else {
            return
        }
        
        let dateNow = Date()
        calendar.timeZone = timeZone
        
        guard
            let hours = calendar.components([.hour], from: dateNow).hour,
            let weekday = calendar.components([.weekday], from: dateNow).weekday
        else {
            return
        }
        
        let days: [SubscribeRequest.Days] = [
            .sunday,
            .monday,
            .tuesday,
            .wednesday,
            .thursday,
            .friday,
            .saturday
        ]
        
        guard let day = days[safe: weekday - 1] else {
            return
        }
        
        let updates = try await Subscription
            .query(on: context.application.db(.psql))
            .all()
            .compactMap {
                SubscribeRequest(chatID: $0.chatID, query: $0.query)
            }
            .filter {
                $0.time == hours && $0.days.contains(day)
            }
            .map { request in           
                let chat = TGChat(id: request.chatID, type: .undefined)
                let entity = TGMessageEntity(type: .botCommand, offset: 0, length: request.command.count + 1)
                let message = TGMessage(messageId: 0, date: 0, chat: chat, text: request.query, entities: [entity])
                
                return TGUpdate(updateId: 0, message: message)
            }
            
        try await TGBOT.connection.dispatcher.process(updates)
    }
}
