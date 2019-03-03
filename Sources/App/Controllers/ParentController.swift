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

    func send(chatID: Int64, text: String) throws -> Future<Message> {
        return try env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: text))
    }
}
