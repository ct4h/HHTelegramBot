//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 21.05.2021.
//

import Foundation
import Vapor
import TelegramVaporBot
import Fluent
import FluentPostgresDriver
import FluentMySQLDriver
import Queues

func configure(_ app: Application) async throws {
    app.logger.logLevel = .debug
    
    app.databases.use(
        .postgres(
            configuration: .init(
                hostname: Environment.get("PSQL_DB_HOST") ?? "localhost",
                port: Environment.get("PSQL_DB_PORT").flatMap { Int($0) } ?? 5432,
                username: Environment.get("PSQL_DB_USER") ?? "",
                database: Environment.get("PSQL_DB_DATABASE"),
                tls: .disable
            )
        ),
        as: .psql
    )
    
    var tls = TLSConfiguration.makeClientConfiguration()
    tls.certificateVerification = .none
    
    app.databases.use(
        .mysql(
            hostname: Environment.get("MySQL_DB_HOST") ?? "localhost",
            port: Environment.get("MySQL_DB_PORT").flatMap { Int($0) } ?? 3360,
            username: Environment.get("MySQL_DB_USER") ?? "",
            password: Environment.get("MySQL_DB_PASSWORD") ?? "",
            database: Environment.get("MySQL_DB_DATABASE"),
            tlsConfiguration: tls
        ),
        as: .mysql
    )
    
    TGBot.log.logLevel = app.logger.logLevel
    
    let bot: TGBot = .init(app: app, botId: Environment.get("TELEGRAM_BOT_TOKEN")!)
    
    await TGBOT.setConnection(try await TGLongPollingConnection(bot: bot))
    
    await SubscriptionsHandles.addHandlers(app: app, connection: TGBOT.connection)
    await HoursHandlers.addHandlers(app: app, connection: TGBOT.connection)
    
    app.queues.schedule(SubscriptionSheduler())
        .hourly()
        .at(0)

    try await TGBOT.connection.start()
    
    try app.queues.startScheduledJobs()
}
