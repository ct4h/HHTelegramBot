import Vapor
import Jobs
import LoggerAPI

class SubscribeScheduler {

    func schedulerHour(action: @escaping (Int, SubscribeRequest.Days) -> Void) {
        guard let calendar = NSCalendar(identifier: .gregorian) else {
            Log.error("Calendar not found")
            return
        }

        var components = calendar.components([.year, .month, .day, .hour, .minute], from: Date())
        components.hour = (components.hour ?? 0) + 1
        components.minute = 0

        guard let date = calendar.date(from: components) else {
            Log.error("Fail create date")
            return
        }

        let delay = date.timeIntervalSince(Date())
        Log.info("Start scheduler after delay \(delay)")

        Jobs.oneoff(delay: .seconds(delay)) {
            self.startJob(interval: .hours(1), action: action)
        }
    }

    private func startJob(interval: Duration, action: @escaping (Int, SubscribeRequest.Days) -> Void) {
        Log.info("schedule job by interval \(interval)")

        Jobs.add(interval: interval) {
            Log.info("job by interval \(interval)")
            if let hours = self.currentHours, let day = self.currentDay {
                action(hours, day)
            }
        }
    }

    var currentHours: Int? {
        guard let calendar = NSCalendar(identifier: .gregorian), let timeZone = TimeZone(secondsFromGMT: 10_800) else {
            return nil
        }


        calendar.timeZone = timeZone
        return calendar.components([.hour], from: Date()).hour
    }

    // TODO: Сделать приватным
    var currentDay: SubscribeRequest.Days? {
        guard let weekday = NSCalendar(identifier: .gregorian)?.components([.weekday], from: Date()).weekday else {
            return nil
        }

        let days: [SubscribeRequest.Days] = [
            .sunday,
            .monday,
            .tuesday,
            .wednesday,
            .thursday,
            .friday,
            .saturday
        ]

        return days[safe: weekday - 1]
    }
}
