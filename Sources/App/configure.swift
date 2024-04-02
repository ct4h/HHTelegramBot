import Vapor
import FluentPostgreSQL
import FluentMySQL

public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
    try services.register(FluentPostgreSQLProvider())
    try services.register(FluentMySQLProvider())

    // Register the configured SQLite database to the database config.
    var databases = DatabasesConfig()
    databases.add(database: postgresDB, as: .psql)
    databases.add(database: mysqlDB, as: .mysql)
    services.register(databases)
    
    let poolConfig = DatabaseConnectionPoolConfig(maxConnections: 1)
    services.register(poolConfig)

    // Configure migrations
    var migrations = MigrationConfig()
    migrations.add(model: Subscription.self, database: .psql)
    migrations.add(migration: DeletePeriodTimeMigration.self, database: .psql)
    services.register(migrations)

    ///Registering bot as a vapor service
    services.register(RedmineBot.self)

    // Other services
    services.register(CustomFieldsRepository.self)
    services.register(TimeEntriesRepository.self)
    services.register(UsersRepository.self)
}

private var postgresDB: PostgreSQLDatabase {
    let arguments = RuntimeArguments.PSQLDataBase()
    let config = PostgreSQLDatabaseConfig(hostname: arguments.hostname,
                                          port: arguments.port,
                                          username: arguments.username,
                                          database: arguments.database,
                                          password: nil,
                                          transport: .cleartext)
    return PostgreSQLDatabase(config: config)
}

private var mysqlDB: MySQLDatabase {
    let arguments = RuntimeArguments.MySQLDataBase()
    let config = MySQLDatabaseConfig(hostname: arguments.hostname,
                                     port: arguments.port,
                                     username: arguments.username,
                                     password: arguments.password,
                                     database: arguments.database)
    return MySQLDatabase(config: config)
}
