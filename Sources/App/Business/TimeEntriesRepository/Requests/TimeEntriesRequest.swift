import Foundation
import Async
import FluentSQL
import MySQL

protocol TimeEntriesRequest {
    typealias TimeEntriesResult = ((TimeEntries, Issue), Project)
    func all(on connection: MySQLDatabase.Connection) -> Future<[TimeEntriesResult]>
}
