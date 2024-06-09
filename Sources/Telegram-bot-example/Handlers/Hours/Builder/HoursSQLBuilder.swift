//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation
import FluentSQL

protocol HoursSQLBuilder {
    func sqlRequest(userFilter: UserFilter?, hoursFilter: HoursFilter) -> SQLQueryString?
}
