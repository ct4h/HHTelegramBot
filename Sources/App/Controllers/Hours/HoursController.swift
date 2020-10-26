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
import FluentSQL
import MySQL

class HoursController: ParentController, CommandsHandler {
    private let hurmaRepository: HurmaRepository
    private let userRepositiry: UsersRepository
    private let timeEntriesRepository: TimeEntriesRepository

    override init(env: BotControllerEnv) {
        if let userRepositiry: UsersRepository = try? env.container.make(), let timeEntriesRepository: TimeEntriesRepository = try? env.container.make() {
            self.userRepositiry = userRepositiry
            self.timeEntriesRepository = timeEntriesRepository
            self.hurmaRepository = HurmaRepository(worker: env.worker)
        } else {
            fatalError()
        }

        super.init(env: env)
    }

    // MARK: - CommandsHandler

    // Подписки гнать через dispatcher
    var handlers: [Handler] {
        let commands: [String: HoursView] = [
            "/hours": DailyHoursView(),
            "/weaklyHours": WeaklyHoursView(),
            "/detailHours": DetailDayHoursView(),
            "/hoursWarnings": DailyHoursWarningsView(),
            "/weaklyOvertimes": WeaklyOvertimeHoursView()
        ]

        return commands.map { (command) -> CommandHandler in
            return CommandHandler(commands: [command.key]) { (update, _) in
                guard let chatID = update.message?.chat.id, let request = HoursRequest(from: update.message?.text) else {
                    // TODO: Выводить хелп сообщение
                    Log.error("Some error handle command \(command.key)")
                    return
                }

                Log.info("Handle command \(command.key)")
                self.handler(chatID: chatID, request: request, view: command.value)
            }
        }
    }

    private func handler(chatID: Int64, request: HoursRequest, view: HoursView) {
        let usersFuture = userRepositiry.users(request: request)
        let hurmaUsersFuture = hurmaRepository.users()
        let timeEntriesFuture = timeEntriesRepository.timeEntries(request: request)

        map(usersFuture, hurmaUsersFuture, timeEntriesFuture) { (users, hurmaUsers, times) -> [HoursResponse] in
            Log.info("Complete extract users count \(users.count)")

            var result: [HoursResponse] = []

            users.forEach { (user) in
                let hurmaUser = hurmaUsers.first(where: { $0.email == user.email })

                let userInfo = HoursResponse.UserInformation(user: user.user, hurmaUser: hurmaUser, fields: user.fields)

                if let time = times.first(where: { $0.userID == user.user.id }) {
                    result.append(HoursResponse(userInformation: userInfo, projects: time.projects))
                } else {
                    result.append(HoursResponse(userInformation: userInfo, projects: []))
                }
            }

            return result.sorted { ($0.userInformation.user.id ?? 0) < ($1.userInformation.user.id ?? 0) }
        }
        .map { view.convert(responses: $0, request: request) }
        .mapIfError { (error) -> [String] in
            return ["\(error)"]
        }
        .whenSuccess { (responses) in
            responses.forEach { text in
                do {
                    _ = try self.send(chatID: chatID, text: text)
                    Log.info("Complete send message")
                } catch {
                    Log.error("Error send message \(error.localizedDescription)")
                }
            }
        }
    }
}
