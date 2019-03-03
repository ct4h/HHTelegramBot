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

protocol HoursControllerView {
    func sendHours(chatID: Int64, filter: FullUserField, date: String, response: [(FullUser, [TimeEntries])])
    func sendHours(chatID: Int64, error: Error)
}

protocol HoursControllerProvider: InlineCommandsHandler {
    func handle(chatID: Int64, query: String, view: HoursControllerView)
}

class HoursController: ParentController, CommandsHandler, InlineCommandsHandler {

    private lazy var paginationManager = {
        return PaginationManager<TimeEntriesResponse>(host: env.constants.redmine.domain,
                                                      port: env.constants.redmine.port,
                                                      access: env.constants.redmine.access,
                                                      worker: env.worker)
    }()

    // MARK: - CommandsHandler

    var handlers: [CommandHandler] {
        return [CommandHandler(commands: ["/hours"], callback: loadHours)]
    }
    
    private func loadHours(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        try inline(query: inlineContext, chatID: chatID, provider: nil)?.throwingSuccess({ (request) in
            try self.sendInlineCommands(chatID: chatID, request: request)
        })
    }

    // MARK: - InlineCommandsHandler

    var inlineContext: String {
        return "hours"
    }

    func inline(query: String, chatID: Int64, provider: InlineCommandsProvider?) throws -> Future<InlineCommandsRequest>? {
        Log.info("hours inline query \(query)")

        let factory: InlineCommandsRequestFactory

        if let request = HoursPeriodRequest(query: query) {
            if let provider = provider {
                provider(chatID, query)
            } else {
                handle(chatID: chatID, request: request, view: self)
            }
            return nil
        } else if let request = HoursGroupRequest(query: query) {
            factory = HoursPeriodsRequestFactory(chatID: chatID, parentRequest: request)
        } else if let request = HoursDepartmentRequest(query: query) {
            factory = HoursGroupsRequestFactory(chatID: chatID, parentRequest: request)
        } else if let request = HoursDepartmentsRequest(query: query) {
            factory = HoursDepartmentsRequestFactory(chatID: chatID, parentRequest: request)
        } else {
            return nil
        }

        let promise = env.worker.eventLoop.newPromise(InlineCommandsRequest.self)
        promise.succeed(result: factory.request)
        return promise.futureResult
    }
}

extension HoursController: HoursControllerProvider {

    func handle(chatID: Int64, query: String, view: HoursControllerView) {
        guard let request = HoursPeriodRequest(query: query) else {
            return
        }

        handle(chatID: chatID, request: request, view: view)
    }

    private func handle(chatID: Int64, request: HoursPeriodRequest, view: HoursControllerView) {
        let userField = FullUserField(name: request.groupRequest.departmentRequest.department,
                                      value: request.groupRequest.group)
        let users = self.users(userField: userField)
        let date = self.date(request: request)

        let promise = timeEntries(users: users, date: date)

        promise.whenSuccess { (response) in
            view.sendHours(chatID: chatID, filter: userField, date: date, response: response)
        }

        promise.whenFailure { (error) in
            view.sendHours(chatID: chatID, error: error)
        }
    }
}

// MARK: - View

extension HoursController: HoursControllerView {

    func sendHours(chatID: Int64, filter: FullUserField, date: String, response: [(FullUser, [TimeEntries])]) {
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

    func sendHours(chatID: Int64, error: Error) {
        let errorText = "Не удалось выполнить команду /hours"
        sendIn(chatID: chatID, text: errorText, error: error)
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
