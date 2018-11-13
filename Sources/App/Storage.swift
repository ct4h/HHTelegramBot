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
}
