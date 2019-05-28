//
//  CustomValue.swift
//  App
//
//  Created by basalaev on 21/04/2019.
//

import Foundation
import FluentMySQL

final class CustomValue: MySQLModel {

    static let entity = "custom_values"

    var id: Int?
    var customized_type: String
    var customized_id: Int
    var custom_field_id: Int
    var value: String

    init(id: Int, customized_type: String, customized_id: Int, custom_field_id: Int, value: String) {
        self.id = id
        self.customized_type = customized_type
        self.customized_id = customized_id
        self.custom_field_id = custom_field_id
        self.value = value
    }
}
