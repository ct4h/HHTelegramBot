//
//  HoursDepartmentsRequest.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

struct HoursDepartmentsRequest {
    let context: String

    init(context: String) {
        self.context = context
    }

    init?(query: String) {
        if let value = query.urlPath {
            self.context = value
        } else {
            return nil
        }
    }

    var query: String {
        return "\(context)"
    }
}
