//
//  HoursController.swift
//  App
//
//  Created by basalaev on 14/11/2018.
//

import Foundation
import Telegrammer
import Async
import LoggerAPI

class HoursController: ParentController, InlineCommandsHandler {

    private lazy var paginationManager = {
        return PaginationManager<TimeEntriesResponse>(host: env.constants.redmine.domain,
                                                      port: env.constants.redmine.port,
                                                      access: env.constants.redmine.access,
                                                      worker: env.worker)
    }()

    func loadHours(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        try inline(query: inlineContext, chatID: chatID, messageID: nil, provider: nil)
    }

    // MARK: - InlineCommandsHandler

    var inlineContext: String {
        return "hours"
    }

    func inline(query: String, chatID: Int64, messageID: Int?, provider: InlineCommandsProvider?) throws {
        Log.info("hours inline query \(query)")

        if let request = HoursPeriodRequest(query: query) {
            if let messageID = messageID {
                try env.bot.deleteMessage(params: .init(chatId: .chat(chatID), messageId: messageID))
            }

            if let provider = provider {
                provider(chatID, query)
            } else {
                handle(chatID: chatID, request: request)
            }
        } else if let request = HoursGroupRequest(query: query) {
            let controller = HoursPeriodsController(env: env)
            try controller.handle(chatID: chatID, messageID: messageID, request: request)
        } else if let request = HoursDepartmentRequest(query: query) {
            let controller = HoursGroupsController(env: env)
            try controller.handle(chatID: chatID, messageID: messageID, request: request)
        } else if let request = HoursDepartmentsRequest(query: query) {
            let controller = HoursDepartmentsController(env: env)
            try controller.handle(chatID: chatID, messageID: messageID, request: request)
        }
    }

    // MARK: -

    private func handle(chatID: Int64, request: HoursPeriodRequest) {
        let userField = FullUserField(name: request.groupRequest.departmentRequest.department,
                                      value: request.groupRequest.group)
        let users = self.users(userField: userField)
        let date = self.date(request: request)

        let promise = timeEntries(users: users, date: date)

        promise.whenSuccess { [weak self] (response) in
            self?.send(chatID: chatID, filter: userField, date: date, response: response)
        }

        promise.whenFailure { [weak self] (error) in
            let errorText = "Не удалось выполнить команду /hours"
            self?.sendIn(chatID: chatID, text: errorText, error: error)
        }
    }
}

// MARK: - Bot callbacks

private extension HoursController {

    func send(chatID: Int64, filter: FullUserField, date: String, response: [(FullUser, [TimeEntries])]) {
        guard chatID != 0 else {
            return
        }

        let items = response.map { (user, timeEntries) -> String in
            let time = timeEntries.reduce(0, { $0 + $1.hours} )
            return "\(time.hoursIcon) \(user.name): \(time.format())"
        }

        let text = "Отчет \(filter.name): \(filter.value) за \(date)\n\n" + items.joined(separator: "\n")

        do {
            try self.env.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: text))
        } catch {
            print(error.localizedDescription)
        }
    }
}


// MARK: - API

private extension HoursController {

    func timeEntries(users: [FullUser], date: String) -> Future<[(FullUser, [TimeEntries])]> {
        let promise = env.worker.eventLoop.newPromise([(FullUser, [TimeEntries])].self)

        env.worker.eventLoop.execute { [weak self] in
            self?._timeEntries(users: users, date: date, buffer: [], promise: promise)
        }

        return promise.futureResult
    }

    func _timeEntries(users: [FullUser], date: String, buffer: [(FullUser, [TimeEntries])], promise: Promise<[(FullUser, [TimeEntries])]>) {
        guard buffer.count < users.count else {
            promise.succeed(result: buffer)
            return
        }

        let user = users[buffer.count]

        let requestPromise = paginationManager.all(requestFactory: { (offset, limit) -> ApiTarget in
            return RedmineRequest.timeEntries(userID: user.id, date: date, offset: offset, limit: limit)
        })

        requestPromise.whenSuccess { [weak self] (timeEntries) in
            let result = buffer + [(user, timeEntries)]
            self?._timeEntries(users: users, date: date, buffer: result, promise: promise)
        }

        requestPromise.whenFailure { (error) in
            promise.fail(error: error)
        }
    }
}

// MARK: - Data

private extension HoursController {

    func users(userField: FullUserField) -> [FullUser] {
        var users = Storage.shared.users.filter({ $0.contains(fields: [userField]) })
        users.sort(by: { $0.name < $1.name })
        return users
    }

    func date(request: HoursPeriodRequest) -> String {
        let date: Date

        switch request.period {
        case .today:
            date = Date()
        case .yesterday:
            date = Date().addingTimeInterval(-86_400) // -сутки
        }

        return date.stringYYYYMMdd
    }
}