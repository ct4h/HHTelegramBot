//
//  DailyHoursView.swift
//  App
//
//  Created by basalaev on 08.01.2020.
//

import Foundation

class DailyHoursView: HoursView {

    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        let usersInfo = responses.compactMap { (response) -> String? in
            if response.isOutstaff {
                return nil
            }

            let isHalfBet = response.isHalfBet
            let totalTime = response.projects.reduce(into: 0) { $0 = $0 + $1.totalTime }
            let hoursIcon = ((isHalfBet ? 2 : 1) * totalTime).hoursIcon

            var components = [hoursIcon]

            if isHalfBet {
                components.append("[½]")
            }

            if totalTime == 0, let nickname = response.nickname {
                components.append(nickname)
            }

            components.append("\(response.user.name):")
            components.append(totalTime.hoursString)

            return components.joined(separator: " ")
        }

        let filter = request.customValues.first ?? request.departments.first ?? ""
        let date = Date().zeroTimeDate?.addingTimeInterval(request.daysOffset * 86_400).stringYYYYMMdd ?? ""

        return ["Отчет \(filter) за \(date)\n\n" + usersInfo.joined(separator: "\n")]
    }
}
