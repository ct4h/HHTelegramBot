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
        guard chatID != 0 else {
            return
        }

        requestNicknames().whenSuccess { (nicknames) in
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

            let items = Array(usersInfo.keys)
                .map { (user) -> (User, Float) in
                    let timeEntries = usersInfo[user] ?? []
                    let time = Float(timeEntries.reduce(0, { $0 + $1.hours}))
                    return (user, time)
                }
                .compactMap { ($0.1 > 0 && $0.1 < 38.0) ? $0 : nil }
                .sorted(by: { $0.1 < $1.1 })
                .map { (value) -> String in
                    let (user, hours) = value

                    let nicknameValue = nicknames.first(where: { (nickname) -> Bool in
                        return user.id == nickname.customized_id
                    })

                    var nickname: String = ""

                    if let nicknameValue = nicknameValue {
                        if nicknameValue.value.first != "@" {
                            nickname = "@" + nicknameValue.value
                        } else {
                            nickname = nicknameValue.value
                        }
                    }

                    return " " + (nickname.isEmpty ? "" : "\(nickname) ") + "\(user.name): \(hours.hoursString)"
            }

            //        let department = request.groupRequest.departmentRequest.department
            //        let group = request.groupRequest.group

            let text = "Рейтинг не трекающих людей\n\n" + items.joined(separator: "\n")
//            let text = "Рейтинг @ct44h @antaresmm"

            do {
                _ = try self.send(chatID: chatID, text: text)
            } catch {
                Log.error("\(error)")
            }
        }
    }

    func sendHours(chatID: Int64, error: Error) {
        let errorText = "Не удалось выполнить команду /weaklyHours"
        sendIn(chatID: chatID, text: errorText, error: error)
    }

    private func requestNicknames() -> Future<[CustomValue]> {
        return env.container.newConnection(to: .mysql)
            .thenFuture { (connection) -> Future<(MySQLConnection, [CustomValue])>? in
                let builder = CustomValue.query(on: connection)
                    .join(\CustomField.id, to: \CustomValue.custom_field_id)
                    .filter(\CustomField.name, .equal, "Telegram аккаунт")

                return builder
                    .all()
                    .map { (connection, $0) }
            }
            .map({ (result) -> [CustomValue] in
                result.0.close()
                return result.1
            })
    }
}
