//
//  WeaklyHoursController.swift
//  App
//
//  Created by basalaev on 15/09/2019.
//

import Foundation
import Telegrammer
import Async
import LoggerAPI
import FluentSQL
import MySQL

/**
 Контроллер формирует отчет по конкретному человеку
 */
class WeaklyHoursController: ParentController, CommandsHandler, InlineCommandsHandler {

    weak var delegate: (HoursControllerProvider & InlineCommandsHandler)?

    // MARK: - CommandsHandler

    var handlers: [Handler] {
        return [CommandHandler(commands: ["/weaklyHours"], callback: weaklyReport)]
        //        return [AuthCommandHandler(bot: env.bot, commands: ["/dayReport"], callback: userReport)]
    }

    private func weaklyReport(_ update: Update, _ context: BotContext?) throws {
        guard let delegate = delegate else {
            Log.info("Delegate not found")
            return
        }

        guard let chatID = update.message?.chat.id else {
            Log.info("Chat id not found")
            return
        }

        try delegate.inline(query: inlineContext, chatID: chatID, provider: nil)?.throwingSuccess({ (request) in
            Log.info("Send inline commands \(chatID) request \(request.context)")
            try self.sendInlineCommands(chatID: chatID, request: request)
        })
    }

    // MARK: - InlineCommandsHandler

    var inlineContext: String {
        return "weaklyHours"
    }

    func inline(query: String, chatID: Int64, provider: InlineCommandsProvider?) throws -> Future<InlineCommandsRequest>? {
        Log.info("reports inline query \(query)")

        return try delegate?.inline(query: query, chatID: chatID, provider: { (chatID, query) in
            Log.info("Calculate weakly reports query \(query)")

            if let provider = provider {
                provider(chatID, query)
            } else {
                self.delegate?.handle(chatID: chatID, query: query, view: self)
            }
        })
    }
}

extension WeaklyHoursController: HoursControllerView {

    func sendHours(chatID: Int64, request: HoursPeriodRequest, date: (from: Date?, to: Date?), response: DBHoursResponse) {
        guard chatID != 0, let date = date.to else {
            return
        }

        var usersInfo: [User: [TimeEntries]] = [:]

        for (user, projects) in response {
            var timeEntries = usersInfo[user] ?? []

            for (_, issues) in projects {
                for value in issues.values {
                    timeEntries += value
                }
            }

            usersInfo[user] = timeEntries
        }

        var users = Array(usersInfo.keys)
        users.sort(by: { $0.name < $1.name })

        let items = users
            .map { (user) -> (User, Float) in
                let timeEntries = usersInfo[user] ?? []
                let time = Float(timeEntries.reduce(0, { $0 + $1.hours}))
                return (user, time)
            }
            .compactMap { $0.1 < 38.0 ? $0 : nil }
            .map { (value) -> String in
                let (user, hours) = value
                return "\(user.name): \(hours.hoursString)"
            }


        let department = request.groupRequest.departmentRequest.department
        let group = request.groupRequest.group

        let text = "Отчет \(department): \(group) за \(date.stringYYYYMMdd)\n\n" + items.joined(separator: "\n")

        do {
            _ = try self.send(chatID: chatID, text: text)
        } catch {
            Log.error("\(error)")
        }
    }

    func sendHours(chatID: Int64, error: Error) {
        let errorText = "Не удалось выполнить команду /weaklyHours"
        sendIn(chatID: chatID, text: errorText, error: error)
    }
}
