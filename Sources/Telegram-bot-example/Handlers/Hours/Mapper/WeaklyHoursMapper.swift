//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 09.06.2024.
//

import Foundation

final class WeaklyHoursMapper: HoursMapper {
    func map(rows: [SQLUserRow], userFilter: UserFilter?, hoursFilter: HoursFilter) -> String {
        let text = rows
            .map { user in
                var components: [String] = []
                
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
                components.append((40 - user.hours).hoursString)
                
                return components.joined(separator: " ")
            }
            .joined(separator: "\n")
    
        let titleMessage = "*Осталось затрекать за \(hoursFilter.description)*"
        
        return [titleMessage, text]
            .joined(separator: "\n\n")
    }
}
