//
//  File.swift
//
//
//  Created by Aleksandr Basalaev on 26.03.2024.
//

import Foundation

class MissedHoursView: HoursView {
    struct UserDetailInfo {
        let name: String
        let nickname: String?
        let totalHours: Float
        let overtimeHours: Float
        
        func notTracked(norma: Float) -> Float {
            return norma - (totalHours - overtimeHours)
        }
        
        func textInfo(norma: Float) -> String {
            let missedHours = notTracked(norma: norma)
            
            var components: [String] = []
            
            if let nick = nickname {
                components.append(nick)
            }
            
            components.append(name)
            components.append(missedHours.hoursString)
            
            if overtimeHours > 0 {
                components.append("(оверы: \(overtimeHours.hoursString))")
            }
            
            return components.joined(separator: " ")
        }
    }
    
    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        guard let stringNormaValue = request.additionalValues.first, let norma = Float(stringNormaValue) else {
            return []
        }
        
        let reportDate = periodDate(request: request)
        
        var result: [String: [UserDetailInfo]] = [:]
        
        for response in responses {
            let overtimes = response.projects.reduce(into: 0) { $0 = $0 + $1.overtimes }
            let total = response.projects.reduce(into: 0) { $0 = $0 + $1.totalTime }
            
            let userDetail = UserDetailInfo(
                name: response.user.name,
                nickname: response.nickname,
                totalHours: total,
                overtimeHours: overtimes
            )

            guard userDetail.notTracked(norma: norma) > 0 else {
                continue
            }
            
            var usersBuffer = result[response.userInformation.department.name] ?? []
            usersBuffer.append(userDetail)
            result[response.userInformation.department.name] = usersBuffer
        }
        
        let departments: [String] = Array(result.keys)
        
        return departments
            .sorted(by: < )
            .compactMap { (department) -> String? in
                guard let users = result[department] else {
                    return nil
                }
                
                var totalMissed: Float = 0
                
                let usersInfo = users
                    .sorted(by: { $0.name < $1.name })
                    .map {
                        totalMissed += $0.notTracked(norma: norma)
                        return $0.textInfo(norma: norma)
                    }
                    .joined(separator: "\n")
                
                switch request.period {
                case .custom:
                    return "*\(department) \(totalMissed.hoursString):*\n" + usersInfo
                default:
                    return "*\(department):*\n" + usersInfo
                }
            }
            .map { resultText in
                return "*Недотрек за \(reportDate)* \(resultText)"
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
    var overtimes: Float {
        return issues.reduce(into: 0) { $0 = $0 + $1.overtimes }
    }
}

private extension IssueResponse {
    var overtimes: Float {
        return timeEntries
            .filter { $0.activity_id == 25 }
            .reduce(into: 0) { $0 = $0 + $1.hours }
    }
}
