//
//  HoursResponse.swift
//  App
//
//  Created by basalaev on 20.01.2020.
//

import Foundation

struct HoursResponse {
    let user: User
    let fields: [CustomFieldsResponse]
    let projects: [ProjectResponse]
}

extension HoursResponse {

    var nickname: String? {
        guard var nickname = (fields.first { $0.name == "Telegram аккаунт" })?.value, !nickname.isEmpty else {
            return nil
        }

        if nickname.first != "@" {
            nickname = "@" + nickname
        }

        return nickname.replacingOccurrences(of: "_", with: "\\_")
    }

    var isOutstaff: Bool {
        return (fields.first { $0.name == "Outstaff" })?.value.bool ?? false
    }

    var isHalfBet: Bool {
        return (fields.first { $0.name == "1/2 ставки" })?.value.bool ?? false
    }
}
