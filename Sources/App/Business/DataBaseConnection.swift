import DatabaseKit
import Service
import Vapor

final class DataBaseConnection: ContainerAlias, DatabaseConnectable {

    /// See `ContainerAlias`.
    static let aliasedContainer: KeyPath<DataBaseConnection, Container> = \.sharedContainer

    // MARK: Services

    let sharedContainer: Container
    let privateContainer: SubContainer

    /// `true` if this request has active connections. This is used to avoid unnecessarily
    /// invoking cached connections release.
    internal var hasActiveConnections: Bool

    // MARK: Init

    public init(container: Container) {
        self.sharedContainer = container
        self.privateContainer = container.subContainer(on: container)
        hasActiveConnections = false
    }

    // MARK: Database

    /// See `DatabaseConnectable`.
    public func databaseConnection<D>(to database: DatabaseIdentifier<D>?) -> Future<D.Connection> {
        guard let database = database else {
            let error = VaporError(
                identifier: "defaultDB",
                reason: "`Model.defaultDatabase` is required to use request as `DatabaseConnectable`.",
                suggestedFixes: [
                    "Ensure you are using the 'model' label when registering this model to your migration config (if it is a migration): migrations.add(model: ..., database: ...).",
                    "If the model you are using is not a migration, set the static `defaultDatabase` property manually in your app's configuration section.",
                    "Use `req.withPooledConnection(to: ...) { ... }` instead."
                ]
            )
            return eventLoop.newFailedFuture(error: error)
        }
        hasActiveConnections = true
        return privateContainer.requestCachedConnection(to: database, poolContainer: self)
    }

    /// Called when the `Request` deinitializes.
    
    deinit {
        if hasActiveConnections {
            try! privateContainer.releaseCachedConnections()
        }
    }
}
