//
//  WeaklyOvertimeHoursView.swift
//  App
//
//  Created by basalaev on 25.10.2020.
//

import Foundation

class WeaklyOvertimeHoursView: HoursView {

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
            .compactMap { (response) -> (Float, String)? in
                if response.isOutstaff {
                    return nil
                }

                let freeDays = response.userInformation.hurmaUser?.freeDaysCount(fromDate: fromDate, toDate: toDate) ?? 0
                let isHalfBet = response.isHalfBet
                let trackedTime = response.projects.reduce(into: 0) { $0 = $0 + $1.totalTime }
                let trackedOvertime = response.projects.reduce(into: 0) { $0 = $0 + $1.overtime }

                let requiredHours = Float((5 - freeDays) * 8 / (isHalfBet ? 2 : 1))
                let overtimeHours = trackedTime - requiredHours

                if overtimeHours > 0 || trackedOvertime > 0 {
                    let untrackedOvertimeStatus = trackedOvertime - overtimeHours

                    var components: [String] = []

                    if let nickname = response.nickname {
                        components.append(nickname)
                    }

                    components.append(response.user.name)
                    components.append("\(overtimeHours) из \(trackedOvertime)")

                    return (overtimeHours, components.joined(separator: " "))
                } else {
                    return nil
                }
            }
            .sorted { $0.0 > $1.0 }
            .map { $0.1 }


        var components: [String] = ["Овертаймы за"]

        components.append("\(fromDate.stringYYYYMMdd) - \(toDate.stringYYYYMMdd)")

        return [components.joined(separator: " ") + "\n\n" + items.joined(separator: "\n")]
    }
}

private extension HurmaUser {

    func freeDaysCount(fromDate: Date, toDate: Date) -> Int {
        let dateFormatter = DateFormatter.yyyyMMdd

        let freeDays = (sick_leave + documented_sick_leave + vacation + unpaid_vacation)
            .compactMap { dateString -> Bool? in
                if let date = dateFormatter.date(from: dateString) {
                    return (date >= fromDate && date <= toDate) ? true : nil
                } else {
                    return nil
                }
            }

        return freeDays.count
    }
}

