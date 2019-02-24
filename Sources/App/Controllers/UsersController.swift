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

class UsersController: ParentController {

    private lazy var paginationManager = {
        return PaginationManager<UsersResponse>(host: env.constants.redmine.domain,
                                                port: env.constants.redmine.port,
                                                access: env.constants.redmine.access,
                                                worker: env.worker)
    }()

    func refreshUsers(_ update: Update, _ context: BotContext?) throws {
        paginationManager.all(requestFactory: { RedmineRequest.users(offset: $0, limit: $1) }).whenSuccess { [weak self] (users) in
            Storage.shared.users = users
            self?.send(text: "Информация пользователей обновлена", updater: update)
        }
    }
}
