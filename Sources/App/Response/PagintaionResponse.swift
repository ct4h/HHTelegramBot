//
//  PagintaionResponse.swift
//  App
//
//  Created by basalaev on 12/11/2018.
//

import Foundation

protocol PagintaionResponse {
    associatedtype ItemsType

    var items: [ItemsType] { get }
    var total_count: Int { get }
    var offset: Int { get }
    var limit: Int { get }
}

extension PagintaionResponse {

    var isFinished: Bool {
        return items.count + offset >= total_count
    }

    var nextOffset: Int {
        return offset + limit
    }
}
