//
//  DailyHoursView.swift
//  App
//
//  Created by basalaev on 08.01.2020.
//

import Foundation

class DailyHoursView: HoursView {

    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        let reportDate = Date().zeroTimeDate?.addingTimeInterval(request.daysOffset * 86_400).stringYYYYMMdd ?? ""

        let usersInfo = responses.compactMap { (response) -> String? in
            if response.isOutstaff {
                return nil
            }

            if response.userInformation.hurmaUser?.isSick(date: reportDate) == true {
                return "😷 \(response.userInformation.user.name)"
            }

            if response.userInformation.hurmaUser?.isVacation(date: reportDate) == true {
                return "🌴 \(response.userInformation.user.name)"
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

            components.append("\(response.userInformation.user.name):")
            components.append(totalTime.hoursString)

            return components.joined(separator: " ")
        }

        let filter = request.customValues.first ?? request.departments.first ?? ""
        return ["*Отчет \(filter) за \(reportDate)*\n\n" + usersInfo.joined(separator: "\n")]
    }
}

private extension HurmaUser {
    func isSick(date: String) -> Bool {
        return (sick_leave + documented_sick_leave).contains(date)
    }

    func isVacation(date: String) -> Bool {
        return (vacation + unpaid_vacation).contains(date)
    }
}
