//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation

enum HoursFilter {
    case day(value: String)
    case range(from: String, to: String)
    
    var condition: String {
        switch self {
        case let .day(value):
            return "spent_on='\(value)'"
        case let .range(from, to):
            return "spent_on>='\(from)' AND spent_on<='\(to)'"
        }
    }
    
    var description: String {
        switch self {
        case let .day(value):
            return value
        case let .range(from, to):
            return "\(from) - \(to)"
        }
    }
    
    var countDays: Int {
        switch self {
        case .day:
            return 1
        case let .range(from, to):
            // TODO: Добавить вычисление рабочих дней внутри диапозона
            return 5
        }
    }
}
