//
//  HoursDepartmentRequest.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation
import LoggerAPI

struct HoursDepartmentRequest {
    let departmentsRequest: HoursDepartmentsRequest
    let department: String

    init(departmentsRequest: HoursDepartmentsRequest, department: String) {
        self.departmentsRequest = departmentsRequest
        self.department = department
    }

    init?(query: String) {
        if let departmentsRequest = HoursDepartmentsRequest(query: query) {
            self.departmentsRequest = departmentsRequest
        } else {
            return nil
        }

        if let department = query.urlParameters["d"] {
            self.department = department
        } else {
            return nil
        }
    }

    var query: String {
        return departmentsRequest.query.appendURL(parameter: "d", value: department)
    }

    var context: String {
        return departmentsRequest.context
    }
}
