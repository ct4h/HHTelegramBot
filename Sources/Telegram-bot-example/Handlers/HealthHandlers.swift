//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 19.06.2024.
//

import Foundation
import Vapor
import TelegramVaporBot
import Fluent
import Algorithms

final class HealthHandlers {
    static func health(app: Vapor.Application, connection: TGConnectionPrtcl, error: Error) async {
        do {
            try await connection.bot.sendMessage(params: .init(chatId: .chat(88432148), text: "\(error)"))
        } catch {
            
        }
    }
}
