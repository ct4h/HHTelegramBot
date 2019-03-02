//
//  ParentController.swift
//  App
//
//  Created by basalaev on 14/11/2018.
//

import Foundation
import Telegrammer
import Vapor
import LoggerAPI

class BotControllerEnv {

    let bot: Bot
    let constants: RuntimeArguments
    let worker: Worker
    let container: Container

    init(bot: Bot, constants: RuntimeArguments, worker: Worker, container: Container) {
        self.bot = bot
        self.constants = constants
        self.worker = worker
        self.container = container
    }
}

class ParentController {

    let env: BotControllerEnv

    init(env: BotControllerEnv) {
        self.env = env
    }

    func send(text: String, updater: Update) {
        guard let message = updater.message else {
            return
        }

        do {
            try self.env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(message.chat.id),
                                                                       text: text))
        } catch {
            Log.error("Error send message \(error.localizedDescription)")
        }
    }

    func sendIn(chatID: Int64, text: String, error: Error) {
        let errorMessage = text + "\n" + error.localizedDescription
        do {
            try env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: errorMessage))
        } catch {
            Log.error(errorMessage)
        }
    }

    func send(chatID: Int64, messageID: Int?, text: String, keyboardMarkup: InlineKeyboardMarkup) throws {
        Log.info("Send buttons chatID \(chatID) messageID \(String(describing: messageID))")

        if let messageID = messageID {
            let params = Bot.EditMessageReplyMarkupParams(chatId: .chat(chatID),
                                                          messageId: messageID,
                                                          inlineMessageId: nil,
                                                          replyMarkup: keyboardMarkup)

            try env.bot.editMessageReplyMarkup(params: params).whenSuccess({ [weak self] result in
                switch result {
                case .bool(let value):
                    if !value, let self = self {
                        self.send(chatID: chatID,
                                  text: text,
                                  markup: .inlineKeyboardMarkup(keyboardMarkup))
                    }
                case .message(_):
                    Log.info("Complete replace message")
                }
            })
        } else {
            self.send(chatID: chatID,
                      text: text,
                      markup: .inlineKeyboardMarkup(keyboardMarkup))
        }
    }

    func send(chatID: Int64, text: String, markup: ReplyMarkup? = nil) {
        do {
            if let markup = markup {
                try env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID),
                                                                      text: text,
                                                                      parseMode: .markdown,
                                                                      replyMarkup: markup))
            } else {
                try env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: text))
            }
        } catch {
            Log.error("Error send message \(error.localizedDescription)")
        }
    }
}
