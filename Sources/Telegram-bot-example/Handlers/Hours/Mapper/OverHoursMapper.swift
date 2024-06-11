//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 11.06.2024.
//

import Foundation

final class OverHoursMapper: HoursMapper {
    func map(rows: [SQLUserRow], userFilter: UserFilter?, hoursFilter: HoursFilter) -> String {
        if rows.isEmpty {
            return "*Переработки за \(hoursFilter.description)* Отсутствуют 🥳"
        }
        
        let hoursRangeLimit = Double(hoursFilter.countDays * 8)
        
        var departments: [String: [String]] = [:]
        
        rows.forEach { user in
            var components: [String] = []
            
            let overtime = (user.total ?? 0) - hoursRangeLimit
            
            if user.hours == 0 {
                // Трек времени без овертаймов
                components.append("🤖")
            } else if hoursRangeLimit + user.hours == user.total  {
                // Все затрекано корректно
                components.append("✅")
            } else {
                // Сумма часов не соотвествует норме
                components.append("💔")
            }
            
            if let nickname = user.telegram_account {
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
            components.append("*\(overtime.hoursString)*")
            components.append("(\(user.hours.hoursString) / \((user.total ?? 0).hoursString))")
            
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
            
        let titleMessage = "*Переработки за \(hoursFilter.description)* 👀"
        
        return [titleMessage, text]
            .joined(separator: "\n\n")
    }
}
