//
//  File.swift
//  
//
//  Created by Oleh Hudeichuk on 21.05.2021.
//

import Foundation
import Vapor
import SwiftTelegramSdk
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
    
    let bot: TGBot = try await .init(
        connectionType: .longpolling(
            limit: nil,
            timeout: nil,
            allowedUpdates: nil),
        dispatcher: nil,
        tgClient: VaporTGClient(client: app.client),
        tgURI: TGBot.standardTGURL,
        botId: Environment.get("TELEGRAM_BOT_TOKEN")!,
        log: app.logger
    )
    
    await botActor.setBot(bot)
    
    await SubscriptionsHandles.addHandlers(bot: bot)
    await HoursHandlers.addHandlers(bot: bot)
    
    try await botActor.bot.start()
    
    app.queues.schedule(SubscriptionSheduler())
        .hourly()
        .at(0)

    try app.queues.startScheduledJobs()
}
