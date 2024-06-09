//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation

enum UserFilter {
    case department(value: String)
    case customField(name: String, value: String)
    
    var joins: [String] {
        switch self {
        case .department:
            return [
                "JOIN people_information as pinfo ON us.id=pinfo.user_id",
                "JOIN departments as dep ON pinfo.department_id=dep.id"
            ]
        case .customField:
            return [
                "JOIN custom_values as cv ON cv.customized_id=us.id"
            ]
        }
    }

    var condition: [String] {
        switch self {
        case .department(let value):
            return ["dep.name='\(value)'"]
        case let .customField(_, value):
            return ["cv.value='\(value)'"]
        }
    }
    
    var description: String {
        switch self {
        case let .department(value):
            return value
        case let .customField(name, value):
            return "\(name): \(value)"
        }
    }
}
