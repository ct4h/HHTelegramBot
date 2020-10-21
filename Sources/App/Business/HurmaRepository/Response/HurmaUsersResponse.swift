//
//  HurmaUsersResponse.swift
//  App
//
//  Created by basalaev on 08.10.2020.
//

import Foundation

struct HurmaUsersResponse: Decodable {
    struct Result: Decodable {
        let data: [HurmaUser]
    }

    let result: Result
}
