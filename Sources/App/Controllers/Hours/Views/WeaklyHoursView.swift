//
//  WeaklyHoursView.swift
//  App
//
//  Created by basalaev on 21.01.2020.
//

import Foundation

class WeaklyHoursView: HoursView {

    func convert(responses: [HoursResponse], request: HoursRequest) -> [String] {
        let items = responses
            .compactMap { (response) -> (Float, String)? in
                if response.isOutstaff {
                    return nil
                }

                let isHalfBet = response.isHalfBet
                let trackedTime = response.projects.reduce(into: 0) { $0 = $0 + $1.totalTime }
                let totalTime = (isHalfBet ? 2 : 1) * trackedTime

                // Костыль чтобы не выводить инфу людей в отпуке
                if totalTime == 0 {
                    return nil
                }

                // Отпрасываем людей затрекавших недельную норму
                if totalTime >= 38.0 {
                    return nil
                }

                var components: [String] = []

                if let nickname = response.nickname {
                    components.append(nickname)
                }

                components.append(response.user.name)

                if isHalfBet {
                    components.append("[½]")
                }

                components.append(trackedTime.hoursString)

                return (totalTime, components.joined(separator: " "))
            }
            .sorted { $0.0 < $1.0 }
            .map { $0.1 }


        var components: [String] = ["Рейтинг нетрекающих людей за"]

        if let date = Date().zeroTimeDate {
            let daySeconds: TimeInterval = 86_400
            if request.period == .weak {
                let fromDate = date.addingTimeInterval((-6 + request.daysOffset) * daySeconds)
                let toDate = date.addingTimeInterval(request.daysOffset * daySeconds)

                components.append("\(fromDate.stringYYYYMMdd) - \(toDate.stringYYYYMMdd)")
            }
        }

        return [components.joined(separator: " ") + "\n\n" + items.joined(separator: "\n")]
    }
}
