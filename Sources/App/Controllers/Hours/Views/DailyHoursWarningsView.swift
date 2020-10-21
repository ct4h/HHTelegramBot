//
//  DailyHoursWarningsView.swift
//  App
//
//  Created by basalaev on 21.10.2020.
//

import Foundation

class DailyHoursWarningsView: HoursView {

    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        let reportDate = Date().zeroTimeDate?.addingTimeInterval(request.daysOffset * 86_400).stringYYYYMMdd ?? ""

        let usersInfo = responses.compactMap { (response) -> String? in
            if response.isOutstaff {
                return nil
            }

            if response.userInformation.hurmaUser?.isSick(date: reportDate) == true {
                return nil
            }

            if response.userInformation.hurmaUser?.isVacation(date: reportDate) == true {
                return nil
            }

            let trackedTime = response.projects.reduce(into: 0) { $0 = $0 + $1.totalTime }
            let standTime = response.projects.reduce(into: 0) { $0 = $0 + $1.standTime }

            var components: [String] = []

            if trackedTime == 0 {
                components.append(Float(0).hoursIcon)
            } else if standTime != 0 {
                components.append("🧍")
                components.append("\(standTime.hoursString)")
            } else {
                return nil
            }

            if let nickname = response.nickname {
                components.append(nickname)
            }

            components.append("\(response.userInformation.user.name)")
            return components.joined(separator: " ")
        }

        let filter = request.customValues.first ?? request.departments.first ?? ""
        return ["*Отчет \(filter) за \(reportDate)*\n\n" + usersInfo.joined(separator: "\n")]
    }
}
