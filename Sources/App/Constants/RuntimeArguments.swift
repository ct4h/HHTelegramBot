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

    let redmine: Redmine
    let telegram: Telegramm

    init(env: Environment) {
        for (key, value) in ProcessInfo.processInfo.environment {
            print("[RuntimeArguments] \(key) - \(value)")
        }

        redmine = Redmine()
        telegram = Telegramm()
    }
}
