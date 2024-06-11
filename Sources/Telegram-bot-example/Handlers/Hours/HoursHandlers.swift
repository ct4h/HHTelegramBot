//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 31.05.2024.
//

import Foundation
import Vapor
import TelegramVaporBot
import Fluent
import FluentSQL
import FluentMySQLDriver

final class HoursHandlers {
    private enum Command: String, CaseIterable {
        /// Команда выводит сумму затреканных часов за период по людям
        /// Если отсутсвует трек времени добавляет ник телеграмма
        /// Сортировка по алфавиту
        /// С иконками какашек
        case hours
        
        /// Команда формирует недельный отчет
        /// Выводятся только тех люди у которых трек времени < 38ч
        /// Сортировка по часам
        /// Ник телеграмма у всех, без иконок (без какашек)
        case weaklyHours
        
        /// Команда формирует недельный отчет
        /// Выводятся только тех люди у которых трек времени < 38ч
        /// Сортировка по часам
        /// Ник телеграмма у всех
        /// С иконками какашек
        case weaklyDepartment
        
        /// Команда формирует отчет по людем затрекавщих простой
        case nonWorkingHours
        
        /// Команда формирует отчет по переработкам
        case overHours
        
        var sqlBuilder: HoursSQLBuilder {
            switch self {
            case .hours:
                return DailyHoursSQLBuilder()
            case .weaklyHours, .weaklyDepartment:
                return WeaklyHoursSQLBuilder()
            case .nonWorkingHours:
                return NonWorkingHoursSQLBuilder()
            case .overHours:
                return OverHoursSQLBuilder()
            }
        }
                
        var mapper: HoursMapper {
            switch self {
            case .hours:
                return DailyHoursMapper()
            case .weaklyHours:
                return WeaklyHoursMapper()
            case .weaklyDepartment:
                return WeaklyDepHoursMapper()
            case .nonWorkingHours:
                return NonWorkingHoursMapper()
            case .overHours:
                return OverHoursMapper()
            }
        }
    }
    
    static func addHandlers(app: Vapor.Application, connection: TGConnectionPrtcl) async {
        for command in Command.allCases {
            await connection.dispatcher.add(TGCommandHandler(commands: ["/\(command.rawValue)"]) { update, bot in
                try await handler(app: app, update: update, bot: bot, sqlBuilder: command.sqlBuilder, mapper: command.mapper)
            })
        }
    }
            
    private static func handler(
        app: Vapor.Application,
        update: TGUpdate,
        bot: TGBot,
        sqlBuilder: HoursSQLBuilder,
        mapper: HoursMapper
    ) async throws {
        guard
            let message = update.message,
            let request = HoursRequest(from: message.text)
        else {
            return
        }
            
        let userFilter = request.userFilter
        
        guard
            let hoursFilter = request.hoursFiler,
            let sql = app.db(.mysql) as? SQLDatabase,
            let sqlRequst = sqlBuilder.sqlRequest(userFilter: userFilter, hoursFilter: hoursFilter)
        else {
            return
        }
        
        let rows = try await sql.raw(sqlRequst)
            .all(decoding: SQLUserRow.self)
        
        let text = mapper.map(rows: rows, userFilter: userFilter, hoursFilter: hoursFilter)
            .replacingOccurrences(of: "_", with: "\\_")
            .replacingOccurrences(of: "-", with: "\\-")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
    
        try await bot.sendMessage(
            params: .init(
                chatId: .chat(message.chat.id),
                text: text,
                parseMode: .markdownV2
            )
        )
    }
}
