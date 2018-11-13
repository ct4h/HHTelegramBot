//
//  RedmineRequest.swift
//  App
//
//  Created by basalaev on 15/12/2018.
//

import Foundation
import HTTP

enum RedmineRequest: ApiTarget {
    case users(offset: Int, limit: Int)
    case timeEntries(userID: Int?, date: String?, offset: Int, limit: Int)

    var path: String {
        switch self {
        case .users:
            return "users.json"
        case .timeEntries:
            return "time_entries.json"
        }
    }

    var parameters: [String : Any]? {
        switch self {
        case let .users(offset, limit):
            return ["offset": offset, "limit": limit]
        case let .timeEntries(userID, date, offset, limit):
            var parameters: [String: Any] = [
                "offset": offset,
                "limit": limit
            ]

            if let userID = userID {
                parameters["user_id"] = userID
            }

            if let date = date {
                parameters["spent_on"] = "\(date)|\(date)"
            }

            return parameters
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
