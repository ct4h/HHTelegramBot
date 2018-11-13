//
//  UsersResponse.swift
//  App
//
//  Created by basalaev on 12/11/2018.
//

import Foundation

struct UsersResponse: Decodable, PagintaionResponse {
    typealias ItemsType = FullUser

    let users: [FullUser]
    let total_count: Int
    let offset: Int
    let limit: Int

    var items: [FullUser] {
        return users
    }
}
