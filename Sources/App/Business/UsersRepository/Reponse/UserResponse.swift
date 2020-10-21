//
//  UserResponse.swift
//  App
//
//  Created by basalaev on 21.01.2020.
//

import Foundation

struct UserResponse {
    let user: User
    let email: String
    let fields: [CustomFieldsResponse]
}
