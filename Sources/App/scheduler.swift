import Vapor
import Jobs
import LoggerAPI

public func schedulerHour(action: @escaping (Int8) -> Void) {
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
        startJob(interval: .hours(1), action: action)
    }
}

private func startJob(interval: Duration, action: @escaping (Int8) -> Void) {
    Log.info("schedule job by interval \(interval)")

    Jobs.add(interval: interval) {
        Log.info("job by interval \(interval)")
        if let hours = currentHours() {
            action(Int8(hours))
        }
    }
}

private func currentHours() -> Int? {
    return NSCalendar(identifier: .gregorian)?.components([.hour], from: Date()).hour
}
