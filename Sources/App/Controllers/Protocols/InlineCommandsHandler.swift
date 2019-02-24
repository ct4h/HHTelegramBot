//
//  InlineCommandsHandler.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation
import Telegrammer
import LoggerAPI

typealias InlineCommandsProvider = (Int64, String) -> Void

protocol InlineCommandsHandler: class {
    var inlineContext: String { get }

    func check(query: String) -> Bool

    func inline(_ update: Update, _ context: BotContext?) throws
    func inline(query: String, chatID: Int64, messageID: Int?, provider: InlineCommandsProvider?) throws
}

extension InlineCommandsHandler {

    var callbackHanler: CallbackQueryHandler {
        return CallbackQueryHandler(pattern: pattern, callback: inline)
    }

    private var pattern: String {
        return "^\(inlineContext).+$"
    }

    func check(query: String) -> Bool {
        return query.matchRegexp(pattern: pattern)
    }

    func inline(_ update: Update, _ context: BotContext?) throws {
        guard let cq = update.callbackQuery, let query = cq.data, let message = cq.message else {
            return
        }

        let charID = message.chat.id
        let messageID = message.messageId

        try inline(query: query, chatID: charID, messageID: messageID, provider: nil)
    }
}
