//
//  HurmaRequests.swift
//  App
//
//  Created by basalaev on 08.10.2020.
//

import Foundation
import HTTP

enum HurmaRequests: ApiTarget {
    case users

    var path: String {
        switch self {
        case .users:
            return "api/v1/out-off-office"
        }
    }

    var parameters: [String : Any]? {
        switch self {
        case .users:
            return ["per_page": 250]
        }
    }

    var method: HTTPMethod {
        return .GET
    }

    var encoding: ParametersEncoding {
        return .url
    }

    var headers: [String : String]? {
        return nil
    }
}

