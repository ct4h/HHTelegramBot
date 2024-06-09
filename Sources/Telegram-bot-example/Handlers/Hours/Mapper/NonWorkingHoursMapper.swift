//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation

final class NonWorkingHoursMapper: HoursMapper {
    func map(rows: [SQLUserRow], userFilter: UserFilter?, hoursFilter: HoursFilter) -> String {
        if rows.isEmpty {
            return "*Простои за \(hoursFilter.description)* Отсутствуют 🥳"
        }
        
        var departments: [String: [String]] = [:]
        
        rows.forEach { user in
            var components: [String] = []
            
            if user.hours == 0, let nickname = user.telegram_account {
                if nickname.first == "@" {
                    components.append(nickname)
                } else {
                    components.append("@" + nickname)
                }
            }
            
            let userName = [user.lastname, user.firstname]
                .compactMap { $0 }
                .joined(separator: " ")
            
            components.append(userName)
            components.append(user.hours.hoursString)
            
            let userString = components.joined(separator: " ")
            
            let department = user.department ?? "null"
            
            var departmentUsers: [String] = departments[department] ?? []
            departmentUsers.append(userString)
            
            departments[department] = departmentUsers
        }
        
        let text = departments.keys
            .sorted(by: <)
            .compactMap { key in
                guard let users = departments[key] else {
                    return nil
                }
                
                return key + ":\n" + users.joined(separator: "\n")
            }
            .joined(separator: "\n\n")
            
        let titleMessage = "*Простои за \(hoursFilter.description)* 👀"
        
        return [titleMessage, text]
            .joined(separator: "\n\n")
    }
}
