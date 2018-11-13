//
//  FullUser.swift
//  App
//
//  Created by basalaev on 12/11/2018.
//

import Foundation

struct FullUser: Decodable {
    let id: Int
    let login: String
    let firstname: String
    let lastname: String
    let custom_fields: [FullUserField]

    var name: String {
        return lastname + " " + firstname
    }

    func contains(fields: [FullUserField]) -> Bool {
        for field in fields {
            let containsField = custom_fields.contains { userField -> Bool in
                return userField.name == field.name && userField.value == field.value
            }
            if !containsField {
                return false
            }
        }

        return true
    }
}

struct FullUserField: Decodable {
    let name: String
    let value: String
}
