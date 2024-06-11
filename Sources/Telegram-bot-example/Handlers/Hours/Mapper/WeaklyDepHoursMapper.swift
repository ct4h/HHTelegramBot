//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation

final class WeaklyDepHoursMapper: HoursMapper {
    func map(rows: [SQLUserRow], userFilter: UserFilter?, hoursFilter: HoursFilter) -> String {
        var text = rows
            .map { user in
                var components: [String] = [
                    (user.hours / Double(hoursFilter.countDays)).hoursIcon
                ]
                
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
                components.append(user.hours.hoursString)
                
                return components.joined(separator: " ")
            }
            .joined(separator: "\n")
    
        if text.isEmpty {
            text = "Все затрекали 🥳"
        }
        
        let titleMessage = "*\(userFilter?.description ?? "") \(hoursFilter.description)*"
        
        return [titleMessage, text]
            .joined(separator: "\n\n")
    }
}

