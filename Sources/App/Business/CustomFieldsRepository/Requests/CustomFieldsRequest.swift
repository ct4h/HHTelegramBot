import Foundation
import Async
import FluentSQL
import MySQL

protocol CustomFieldsRequest {
    func all(on connection: MySQLDatabase.Connection) -> Future<[(CustomField, CustomValue)]>
}

extension CustomFieldsRequest {
    func all(on connection: MySQLDatabase.Connection) -> Future<[(CustomField, CustomValue)]> {
        return CustomField.query(on: connection)
            .filter(\CustomField.type, .equal, CustomField.FieldType.user.rawValue)
            .join(\CustomValue.custom_field_id, to: \CustomField.id)
            .alsoDecode(CustomValue.self)
            .all()
    }
}
