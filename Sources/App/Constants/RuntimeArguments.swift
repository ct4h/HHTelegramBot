import Foundation
import Vapor

struct RuntimeArguments {

    struct Telegramm {
        let token: String

        init() {
            if let value = Environment.get("TELEGRAM_BOT_TOKEN") {
                token = value
            } else {
                fatalError("Cannot find telegramm token")
            }
        }
    }

    struct PSQLDataBase {
        let hostname: String
        let port: Int
        let username: String
        let database: String

        private enum Keys: String {
            case hostname = "PSQL_DB_HOST"
            case port = "PSQL_DB_PORT"
            case username = "PSQL_DB_USER"
            case database = "PSQL_DB_DATABASE"
        }

        init() {
            if let value = Environment.get(Keys.hostname.rawValue) {
                hostname = value
            } else {
                hostname = "localhost"
            }

            if let value = Environment.get(Keys.port.rawValue) {
                port = Int(value) ?? 0
            } else {
                port = 5432
            }

            if let value = Environment.get(Keys.username.rawValue) {
                username = value
            } else {
                fatalError("Cannot find psql db username")
            }

            if let value = Environment.get(Keys.database.rawValue) {
                database = value
            } else {
                fatalError("Cannot find psql db database")
            }
        }
    }

    struct MySQLDataBase {
        let hostname: String
        let port: Int
        let username: String
        let password: String
        let database: String

        private enum Keys: String {
            case hostname = "MySQL_DB_HOST"
            case port = "MySQL_DB_PORT"
            case username = "MySQL_DB_USER"
            case password = "MySQL_DB_PASSWORD"
            case database = "MySQL_DB_DATABASE"
        }

        init() {
            if let value = Environment.get(Keys.hostname.rawValue) {
                hostname = value
            } else {
                hostname = "localhost"
            }

            if let value = Environment.get(Keys.port.rawValue) {
                port = Int(value) ?? 0
            } else {
                port = 3306
            }

            if let value = Environment.get(Keys.username.rawValue) {
                username = value
            } else {
                fatalError("Cannot find mysql db username")
            }

            if let value = Environment.get(Keys.password.rawValue) {
                password = value
            } else {
                fatalError("Cannot find mysql db password")
            }

            if let value = Environment.get(Keys.database.rawValue) {
                database = value
            } else {
                fatalError("Cannot find mysql db database")
            }
        }
    }

    let telegram: Telegramm

    init(env: Environment) {
        telegram = Telegramm()
    }
}
