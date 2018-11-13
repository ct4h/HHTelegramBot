//
//  TimeEntriesResponse.swift
//  App
//
//  Created by basalaev on 12/11/2018.
//

import Foundation

struct TimeEntriesResponse: Decodable, PagintaionResponse {
    typealias ItemsType = TimeEntries

    let time_entries: [TimeEntries]
    let total_count: Int
    let offset: Int
    let limit: Int

    var items: [TimeEntries] {
        return time_entries
    }
}
