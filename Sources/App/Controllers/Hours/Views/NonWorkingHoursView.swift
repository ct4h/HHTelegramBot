//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 26.03.2024.
//

import Foundation

class NonWorkingHoursView: HoursView {

    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        let reportDate = Date().zeroTimeDate?.addingTimeInterval(request.daysOffset * 86_400).stringYYYYMMdd ?? ""

        let usersInfo = responses
            .compactMap { (response) -> String? in
                let nonWorkingHours = response.projects.reduce(into: 0) { $0 = $0 + $1.nonWorkingHours }

                guard nonWorkingHours > 0 else {
                    return nil
                }
                
                var components: [String] = []
                
                if let nickname = response.nickname {
                    components.append(nickname)
                }
                
                components.append(response.user.name)
                components.append(nonWorkingHours.hoursString)

                return "\(components.joined(separator: " "))"
            }
        
        if usersInfo.isEmpty {
            return ["*Простои за \(reportDate)* Отсутствуют 🥳"]
        } else {
            return ["*Простои за \(reportDate)* 👀\n\n" + usersInfo.joined(separator: "\n")]
        }
    }
}

private extension ProjectResponse {
    var nonWorkingHours: Float {
        return issues.reduce(into: 0) { $0 = $0 + $1.nonWorkingHours }
    }
}

private extension IssueResponse {
    var nonWorkingHours: Float {
        if issue.subject.lowercased().contains("простой") {
            return totalTime
        }
        
        return timeEntries
            .reduce(into: 0) {
                if $1.activity_id == 37 || $1.comments.lowercased().contains("простой")  {
                    $0 = $0 + $1.hours
                }
            }
    }
}
