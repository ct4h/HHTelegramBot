//
//  Storage.swift
//  App
//
//  Created by basalaev on 14/11/2018.
//

import Foundation

class Storage {
    static let shared = Storage()

    var users: [FullUser] = []

    private init() {}

    func search(nickname: String) -> Bool {
        let user = users.first(where: { (user) -> Bool in
            let field = user.custom_fields.first(where: { (field) -> Bool in
                return field.name == "Telegram аккаунт"
            })
            return field?.value == nickname
        })
        return user != nil
    }
}
