//
//  HurmaUser.swift
//  App
//
//  Created by basalaev on 08.10.2020.
//

import Foundation

struct HurmaUser: Decodable {
    let id: String
    let email: String

    // Даты больничного
    let sick_leave: [String]
    let documented_sick_leave: [String]

    // Даты отпусков
    let vacation: [String]
    let unpaid_vacation: [String]
}
