//
//  HoursResponse.swift
//  App
//
//  Created by basalaev on 20.01.2020.
//

import Foundation

struct HoursResponse {
    struct UserInformation {
        let user: User
        let hurmaUser: HurmaUser?
        let fields: [CustomFieldsResponse]
    }

    let userInformation: UserInformation
    let projects: [ProjectResponse]

    var user: User {
        return userInformation.user
    }
}

extension HoursResponse {
    var nickname: String? {
        guard var nickname = (userInformation.fields.first { $0.name == "Telegram аккаунт" })?.value, !nickname.isEmpty else {
            return nil
        }

        if nickname.first != "@" {
            nickname = "@" + nickname
        }

        return nickname.replacingOccurrences(of: "_", with: "\\_")
    }

    var isOutstaff: Bool {
        return (userInformation.fields.first { $0.name == "Outstaff" })?.value.bool ?? false
    }

    var isHalfBet: Bool {
        return (userInformation.fields.first { $0.name == "1/2 ставки" })?.value.bool ?? false
    }
}
