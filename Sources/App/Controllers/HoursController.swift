//
//  HoursController.swift
//  App
//
//  Created by basalaev on 14/11/2018.
//

import Foundation
import Telegrammer
import Async

class HoursController: ParentController {

    private lazy var paginationManager = {
        return PaginationManager<TimeEntriesResponse>(host: constants.redmine.domain,
                                                      port: constants.redmine.port,
                                                      access: constants.redmine.access,
                                                      worker: worker)
    }()

    func loadHours(_ update: Update, _ context: BotContext?) throws {
        guard let chatID = update.message?.chat.id else {
            return
        }

        try send(chatID: chatID,
                 text: "Какой отчет подготовить?",
                 markup: buttons(titles: usersCustomFields, callbackData: String(chatID)))
    }

    func inline(_ update: Update, _ context: BotContext?) throws {
        guard let query = update.callbackQuery?.data else {
            return
        }

        print("Query \(query)")

        let inputData = HoursRequestInputData(query: query)

        if let userField = inputData.userField {
            // Выполняем запрос
            let users = filterUsers(field: userField)

            let date = Date.stringYYYYMMdd
            print("Make date \(date)")

            timeEntries(users: users, date: date).whenSuccess { [weak self] (response) in
                self?.send(chatID: inputData.chatID, filter: userField, date: date, response: response)
            }
        } else if let fieldName = inputData.fieldName {
            // Генерим кнопки для выбора значения фильтра
            let buttons = self.buttons(titles: fieldValues(fieldName: fieldName), callbackData: query)
            try send(chatID: inputData.chatID, text: "Какой отчет подготовить?", markup: buttons)
        } else {
            // Шлем ошибку
        }
    }

    private func buttons(titles: [String], callbackData: String) -> ReplyMarkup {
        var buttons: [[InlineKeyboardButton]] = []
        for title in titles {
            buttons.append([InlineKeyboardButton(text: title, callbackData: "\(callbackData)/\(title)")])
        }
        return .inlineKeyboardMarkup(InlineKeyboardMarkup(inlineKeyboard: buttons))
    }
}

// MARK: - Bot callbacks

private extension HoursController {

    func send(chatID: Int64, text: String, markup: ReplyMarkup) throws {
        guard chatID != 0 else {
            return
        }

        try self.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID),
                                                               text: text,
                                                               parseMode: .markdown,
                                                               replyMarkup: markup))
    }

    func send(chatID: Int64, filter: FullUserField, date: String, response: [(FullUser, [TimeEntries])]) {
        guard chatID != 0 else {
            return
        }

        let items = response.map { (user, timeEntries) -> String in
            let time = timeEntries.reduce(0, { $0 + $1.hours} )
            return "\(time.userFriendly) \(user.name): \(time.format(f: ".2"))"
        }

        let text = "Отчет \(filter.name): \(filter.value) за \(date)\n\n" + items.joined(separator: "\n")

        do {
            try self.bot.sendMessage(params: Bot.SendMessageParams(chatId: .chat(chatID), text: text))
        } catch {
            print(error.localizedDescription)
        }
    }
}


// MARK: - API

private extension HoursController {

    func timeEntries(users: [FullUser], date: String) -> Future<[(FullUser, [TimeEntries])]> {
        let promise = worker.eventLoop.newPromise([(FullUser, [TimeEntries])].self)

        worker.eventLoop.execute { [weak self] in
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

        paginationManager.all(requestFactory: { (offset, limit) -> ApiTarget in
            return RedmineRequest.timeEntries(userID: user.id, date: date, offset: offset, limit: limit)
        }).whenSuccess { [weak self] (timeEntries) in
            let result = buffer + [(user, timeEntries)]
            self?._timeEntries(users: users, date: date, buffer: result, promise: promise)
        }
    }
}

// MARK: - Data

private extension HoursController {

    var usersCustomFields: [String] {
        var fields: Set<String> = []

        for user in Storage.shared.users {
            for field in user.custom_fields {
                fields.insert(field.name)
            }
        }

        var objects = Array(fields)
        objects.sort(by: { $0 < $1 })
        return objects
    }

    func fieldValues(fieldName: String) -> [String] {
        var values: Set<String> = []

        for user in Storage.shared.users {
            for userField in user.custom_fields where userField.name == fieldName && userField.value != "" {
                values.insert(userField.value)
            }
        }

        var objects = Array(values)
        objects.sort(by: { $0 < $1 })
        return objects
    }

    func filterUsers(field: FullUserField) -> [FullUser] {
        var users = Storage.shared.users.filter({ $0.contains(fields: [field]) })
        users.sort(by: { $0.name < $1.name })
        return users
    }
}

struct HoursRequestInputData {
    let chatID: Int64
    let fieldName: String?
    let fieldValue: String?

    init(query: String) {
        let components = query.components(separatedBy: "/")

        if let value = components[safe: 0] {
            chatID = Int64(value) ?? 0
        } else {
            chatID = 0
        }

        if let value = components[safe: 1] {
            fieldName = value
        } else {
            fieldName = nil
        }

        if let value = components[safe: 2] {
            fieldValue = value
        } else {
            fieldValue = nil
        }
    }

    var userField: FullUserField? {
        if let fieldName = fieldName, let fieldValue = fieldValue {
            return FullUserField(name: fieldName, value: fieldValue)
        } else {
            return nil
        }
    }
}

private extension Double {

    var userFriendly: String {
        if self == 0 {
            return "💩"
        } else if self >= 14 {
            return "☠️"
        } else if self >= 10 {
            return "🤖"
        } else if self >= 8.5 {
            return "👑"
        } else if self >= 7.5 {
            return "✅"
        } else {
            return "💔"
        }
    }
}

extension Array {
    subscript (safe index: Int) -> Element? {
        return (0..<count).contains(index) ? self[index] : nil
    }
}

extension Double {
    func format(f: String) -> String {
        return String(format: "%\(f)f", self)
    }
}
