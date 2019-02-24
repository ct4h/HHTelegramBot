import Foundation
import Vapor

struct RuntimeArguments {
    struct Redmine {
        let domain: String
        let port: Int
        let access: String

        private enum Keys: String {
            case domain = "REDMAIN_HOST"
            case port = "REDMAIN_PORT"
            case access = "REDMAIN_ACCESS"
        }

        init() {
            if let value = Environment.get(Keys.domain.rawValue) {
                domain = value
            } else {
                fatalError("Cannot find redmine domain")
            }

            if let value = Environment.get(Keys.port.rawValue) {
                port = Int(value) ?? 0
            } else {
                fatalError("Cannot find redmine port")
            }

            if let value = Environment.get(Keys.access.rawValue) {
                access = value
            } else {
                fatalError("Cannot find redmine access")
            }
        }
    }

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

    struct DataBase {
        let hostname: String
        let port: Int
        let username: String
        let database: String

        private enum Keys: String {
            case hostname = "DB_HOST"
            case port = "DB_PORT"
            case username = "DB_USER"
            case database = "DB_DATABASE"
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
                fatalError("Cannot find db username")
            }

            if let value = Environment.get(Keys.database.rawValue) {
                database = value
            } else {
                fatalError("Cannot find db database")
            }
        }
    }

    let redmine: Redmine
    let telegram: Telegramm

    init(env: Environment) {
        redmine = Redmine()
        telegram = Telegramm()
    }
}
