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

struct InlineCommandsRequest {
    let context: String
    let title: String
    let values: [InlineButtonData]
}

struct InlineButtonData {
    let title: String
    let query: String
}

protocol InlineCommandsRequestFactory {
    var request: InlineCommandsRequest { get }
}

protocol InlineCommandsHandler: class {
    var inlineContext: String { get }

    func check(query: String) -> Bool

    func inline(_ update: Update, _ context: BotContext?) throws
    func inline(query: String, chatID: Int64, provider: InlineCommandsProvider?) throws -> Future<InlineCommandsRequest>?
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
}

extension InlineCommandsHandler where Self: ParentController {

    /**
     Алгоритм обработки отправки сообщения:
     1) Удаляем сообщение по которому пришел ответ
     2) Восстонавливаем оригинальный запрос
     3) Удалеям из буфера ранее сохраную группу
     4) Создаем группу для проксирования запросов
     5) Отправляем сообщение
     6) Когда отправили сообщение сохраняем его данные в группе
     */
    func inline(_ update: Update, _ context: BotContext?) throws {
        guard let cq = update.callbackQuery, let data = cq.data, let message = cq.message else {
            return
        }

        let chatID = message.chat.id
        let messageID = message.messageId

        guard let username = message.from?.username, Storage.shared.search(nickname: username) else {
            do {
                let errorMessage = "Access denied"
                try env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: errorMessage))
            } catch {
                Log.info("error \(error)")
            }
            return
        }

        try deleteMessage(chatID: chatID, messageID: message.messageId)
            .thenFuture { (_) -> Future<InlineCommandsRequest>? in
                if let query = InlineCommandsBuffer.shared.query(callbackData: data) {
                    return try self.inline(query: query, chatID: chatID, provider: nil)
                } else {
                    Log.error("Not found query \(data)")
                    return nil
                }
            }
            .thenThrowing { (value) -> InlineCommandsRequest in
                InlineCommandsBuffer.shared.deleteGroup(chatID: chatID, messageID: messageID)
                return value
            }
            .thenFuture { (request) -> Future<(Message, InlineCommandsGroup)>? in
                return try self.message(chatID: chatID, request: request)
            }.whenSuccess { (result) in
                InlineCommandsBuffer.shared.update(group: result.1, chatID: result.0.chat.id, messageID: result.0.messageId)
            }
    }

    func sendInlineCommands(chatID: Int64, request: InlineCommandsRequest?) throws {
        try message(chatID: chatID, request: request)?.whenSuccess({ (result) in
            InlineCommandsBuffer.shared.update(group: result.1, chatID: result.0.chat.id, messageID: result.0.messageId)
        })
    }

    // MARK: -

    private func deleteMessage(chatID: Int64, messageID: Int) throws -> Future<Bool> {
        return try env.bot.deleteMessage(params: Bot.DeleteMessageParams(chatId: .chat(chatID), messageId: messageID))
    }

    private func message(chatID: Int64, request: InlineCommandsRequest?) throws -> Future<(Message, InlineCommandsGroup)>? {
        guard let request = request else {
            return nil
        }

        var buttons: [[InlineKeyboardButton]] = []
        let queries = request.values.map { $0.query }
        let group = InlineCommandsBuffer.shared.registrate(context: request.context, queries: queries)

        zip(request.values, group.queries).forEach { (item) in
            buttons.append([InlineKeyboardButton(text: item.0.title, callbackData: item.1)])
        }

        let params = Bot.SendMessageParams(chatId: .chat(chatID),
                                       text: request.title,
                                       parseMode: .markdown,
                                       replyMarkup: .inlineKeyboardMarkup(InlineKeyboardMarkup(inlineKeyboard: buttons)))

        return try env.bot.sendMessage(params: params).thenThrowing({ (message) -> (Message, InlineCommandsGroup) in
            return (message, group)
        })
    }
}
