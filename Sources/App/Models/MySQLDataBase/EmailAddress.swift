//
//  EmailAddress.swift
//  App
//
//  Created by basalaev on 08.10.2020.
//

import Foundation
import FluentMySQL

struct EmailAddress: MySQLModel {
    static let entity = "email_addresses"

    var id: Int?
    var user_id: Int
    var address: String

    init(id: Int, user_id: Int, address: String) {
        self.id = id
        self.user_id = user_id
        self.address = address
    }
}
