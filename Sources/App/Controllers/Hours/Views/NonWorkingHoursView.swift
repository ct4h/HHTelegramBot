//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 26.03.2024.
//

import Foundation

class NonWorkingHoursView: HoursView {

    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        let reportDate = periodDate(request: request)
        
        var result: [String: ([(String, String)], Float)] = [:]
        
        for response in responses {
            let nonWorkingHours = response.projects.reduce(into: 0) { $0 = $0 + $1.nonWorkingHours }

            guard nonWorkingHours > 0 else {
                continue
            }
            
            var components: [String] = []
            
            if let nickname = response.nickname {
                components.append(nickname)
            }
            
            components.append(response.user.name)
            components.append(nonWorkingHours.hoursString)

            let userResult = "\(components.joined(separator: " "))"
            
            if var (buffer, total) = result[response.userInformation.department.name] {
                buffer.append((userResult, response.user.name))
                total += nonWorkingHours
                result[response.userInformation.department.name] = (buffer, total)
            } else {
                result[response.userInformation.department.name] = ([(userResult, response.user.name)], nonWorkingHours)
            }
        }
        
        let departments: [String] = Array(result.keys)
        
        let resultText = departments
            .sorted(by: < )
            .compactMap { (department) -> String? in
                guard let (values, total) = result[department] else {
                    return nil
                }
                
                let usersInfo = values
                    .sorted(by: { $0.1 < $1.1 })
                    .map { $0.0 }
                    .joined(separator: "\n")
                
                switch request.period {
                case .custom:
                    return "\(department) \(total.hoursString):\n" + usersInfo
                default:
                    return "\(department):\n" + usersInfo
                }
            }
            .joined(separator: "\n\n")
        
        if resultText.isEmpty {
            return ["*Простои за \(reportDate)* Отсутствуют 🥳"]
        } else {
            return ["*Простои за \(reportDate)* 👀\n\n" + resultText]
        }
    }
    
    func periodDate(request: HoursRequest) -> String {
        guard let nowDate = Date().zeroTimeDate else {
            return ""
        }
        
        switch request.period {
        case .day:
            return nowDate.addingTimeInterval(request.daysOffset * 86_400).stringYYYYMMdd
        case .weak:
            let daySeconds: TimeInterval = 86_400

            let fromDate = nowDate.addingTimeInterval((-6 + request.daysOffset) * daySeconds)
            let toDate = nowDate.addingTimeInterval(request.daysOffset * daySeconds)
            
            return "\(fromDate.stringYYYYMMdd) - \(toDate.stringYYYYMMdd)"
        case let .custom(from, to):
            return "\(from) - \(to)"
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
        let subject = issue.subject.lowercased()
        
        if subject.contains("простои") || subject.contains("простой") {
            return totalTime
        }

        return timeEntries
            .filter {
                if $0.activity_id == 37 {
                    return true
                }
                
                let comments = $0.comments.lowercased()
                return comments.contains("простои") || comments.contains("простой")
            }
            .reduce(into: 0) {
                $0 = $0 + $1.hours
            }
    }
}
