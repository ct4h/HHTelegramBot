//
//  ParentController.swift
//  App
//
//  Created by basalaev on 14/11/2018.
//

import Foundation
import Telegrammer
import Vapor

class ParentController {

    let bot: Bot
    let constants: RuntimeArguments
    let worker: Worker

    init(bot: Bot, constants: RuntimeArguments, worker: Worker) {
        self.bot = bot
        self.constants = constants
        self.worker = worker
    }

    func send(text: String, updater: Update) {
        guard let message = updater.message else {
            return
        }

        do {
            try self.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(message.chat.id),
                                                                   text: text))
        } catch {
            print(error.localizedDescription)
        }
    }
}
