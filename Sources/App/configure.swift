import Vapor
import FluentPostgreSQL

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {

    try services.register(FluentPostgreSQLProvider())

    // Configure a SQLite database
    let dbArguments = RuntimeArguments.DataBase()
    let config = PostgreSQLDatabaseConfig(hostname: dbArguments.hostname,
                                          port: dbArguments.port,
                                          username: dbArguments.username,
                                          database: dbArguments.database,
                                          password: nil,
                                          transport: .cleartext)
    let postgres = PostgreSQLDatabase(config: config)

    // Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: postgres, as: .psql)
    services.register(databases)

    // Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: Subscription.self, database: .psql)
    services.register(migrations)

    ///Registering bot as a vapor service
    services.register(RedmineBot.self)
}

