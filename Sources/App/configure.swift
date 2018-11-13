import Vapor

/// Called before your application initializes.
public func configure(_ config: inout Config, _ env: inout Environment, _ services: inout Services) throws {
//    var middlewareConfig = MiddlewareConfig()
//    middlewareConfig.use(ErrorMiddleware.self)
//    services.register(middlewareConfig)

    ///Registering bot as a vapor service
    services.register(RedmineBot.self)
}

