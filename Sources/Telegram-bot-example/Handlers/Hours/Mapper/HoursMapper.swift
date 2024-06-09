//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation

protocol HoursMapper {
    func map(rows: [SQLUserRow], userFilter: UserFilter?, hoursFilter: HoursFilter) -> String
}
