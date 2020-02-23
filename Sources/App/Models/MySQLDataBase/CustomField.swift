//
//  CustomField.swift
//  App
//
//  Created by basalaev on 21/04/2019.
//

import Foundation
import FluentMySQL

final class CustomField: MySQLModel {

    static let entity = "custom_fields"

    var id: Int?
    var type: String
    var name: String
    var field_format: String
    var possible_values: String?

    init(id: Int, type: String, name: String, field_format: String, possible_values: String?) {
        self.id = id
        self.type = type
        self.name = name
        self.field_format = field_format
        self.possible_values = possible_values
    }
}

extension CustomField {
    enum FieldType: String {
        case user = "UserCustomField"
    }
}

extension CustomField {

    var values: [String] {
        guard let possible_values = possible_values else {
            return []
        }

        let values = possible_values.components(separatedBy: "\n- ")
        
        if values.count > 1 {
            return Array(values[1...])
        } else {
            return []
        }
    }
}
