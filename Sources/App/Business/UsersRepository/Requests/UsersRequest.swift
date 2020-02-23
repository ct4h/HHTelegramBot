import Foundation
import Async
import FluentSQL
import MySQL

protocol UsersRequest: CustomFieldsRequest {
    func all(on connection: MySQLDatabase.Connection) -> Future<[User]>
}
