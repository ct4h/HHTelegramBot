//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation

extension HoursRequest {
    var hoursFiler: HoursFilter? {
        guard let date = Date().zeroTimeDate else {
            return nil
        }
        
        let dateFormatter = DateFormatter.yyyyMMdd
        let daySeconds: TimeInterval = 86_400
                
        switch period {
        case .day:
            let reportDate = date.addingTimeInterval(daysOffset * daySeconds)
            let reportDateString = dateFormatter.string(from: reportDate)
            
            return .day(value: reportDateString)
        case .weak:
            let fromDate = dateFormatter.string(from: date.addingTimeInterval((-6 + daysOffset) * daySeconds))
            let toDate = dateFormatter.string(from: date.addingTimeInterval(daysOffset * daySeconds))

            return .range(from: fromDate, to: toDate)
        case let .custom(fromDate, toDate):
            return .range(from: fromDate, to: toDate)
        }
    }
    
    var userFilter: UserFilter? {
        if let department = departments.first {
            return .department(value: department)
        }
        
        if let customField = customFields.first, let customValue = customValues.first {
            return .customField(name: customField, value: customValue)
        }
        
        return nil
    }
}

