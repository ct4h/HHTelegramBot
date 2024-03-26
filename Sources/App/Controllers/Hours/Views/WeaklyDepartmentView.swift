//
//  DailyHoursView.swift
//  App
//
//  Created by basalaev on 08.01.2020.
//

import Foundation

class WeaklyDepartmentView: HoursView {

    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        if let date = Date().zeroTimeDate, request.period == .weak {
            let daySeconds: TimeInterval = 86_400

            return convert(
                fromDate: date.addingTimeInterval((-6 + request.daysOffset) * daySeconds),
                toDate: date.addingTimeInterval(request.daysOffset * daySeconds),
                responses: responses,
                request: request
            )
        }

        return []
    }
    
    private func convert(fromDate: Date, toDate: Date, responses: [HoursResponse], request: HoursRequest) -> [String] {
        let items = responses
            .compactMap { (response) -> (Int, String)? in
                if response.isOutstaff {
                    return nil
                }

                let isHalfBet = response.isHalfBet
                let trackedTime = response.projects.reduce(into: 0) { $0 = $0 + $1.totalTime }
            
                var components: [String] = [(trackedTime / 5).hoursIcon]
                
                if let nickname = response.nickname {
                    components.append(nickname)
                }

                components.append(response.user.name)

                if isHalfBet {
                    components.append("[½]")
                }

                components.append(trackedTime.hoursString)

                return (response.user.id ?? 0, components.joined(separator: " "))
            }
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }

        var components: [String] = []
        
        if let department = request.departments.first {
            components.append(department)
        } else if let value = request.customValues.first {
            components.append(value)
        }

        components.append("\(fromDate.stringYYYYMMdd) - \(toDate.stringYYYYMMdd)")

        return [components.joined(separator: " ") + "\n\n" + items.joined(separator: "\n")]
    }
}
