//
//  HoursGroupRequest.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

struct HoursGroupRequest {
    let departmentRequest: HoursDepartmentRequest
    let group: String

    init(departmentRequest: HoursDepartmentRequest, group: String) {
        self.departmentRequest = departmentRequest
        self.group = group
    }

    init?(query: String) {
        if let departmentRequest = HoursDepartmentRequest(query: query) {
            self.departmentRequest = departmentRequest
        } else {
            return nil
        }

        if let group = query.urlParameters["g"] {
            self.group = group
        } else {
            return nil
        }
    }

    var query: String {
        return departmentRequest.query.appendURL(parameter: "g", value: group)
    }

    var context: String {
        return departmentRequest.context
    }
}
