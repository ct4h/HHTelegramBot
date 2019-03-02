//
//  UsersController.swift
//  App
//
//  Created by basalaev on 14/11/2018.
//

import Foundation
import Telegrammer
import Async
import NIO
import Vapor
import LoggerAPI

class UsersController: ParentController, CommandsHandler {

    private lazy var paginationManager = {
        return PaginationManager<UsersResponse>(host: env.constants.redmine.domain,
                                                port: env.constants.redmine.port,
                                                access: env.constants.redmine.access,
                                                worker: env.worker)
    }()

    // MARK: - CommandsHandler

    var handlers: [CommandHandler] {
        return [CommandHandler(commands: ["/refreshUsers"], callback: refreshUsers)]
    }

    private func refreshUsers(_ update: Update, _ context: BotContext?) throws {
        guard let message = update.message else {
            send(text: "Не удалось определить пользователя", updater: update)
            return
        }

        let promise = paginationManager.all(requestFactory: { RedmineRequest.users(offset: $0, limit: $1) })

        promise.whenSuccess { [weak self] (users) in
            Storage.shared.users = users
            self?.send(text: "Информация пользователей обновлена", updater: update)
        }

        promise.whenFailure { [weak self] error in
            Log.info("Error send request users \(error)")
            let text = "Не удалось выполнить команду /refreshUsers"
            self?.sendIn(chatID: message.chat.id, text: text, error: error)
        }
    }
}
