//
//  TimeEntries.swift
//  App
//
//  Created by basalaev on 12/11/2018.
//

import Foundation

struct TimeEntries: Decodable {
    let id: Int
    let hours: Double
    let comments: String
    let user: ShortUser
    let project: Project
}
