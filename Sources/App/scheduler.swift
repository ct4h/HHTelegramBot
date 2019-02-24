import Vapor
import Jobs
import LoggerAPI

public struct SchedulerTime {
    let hours: Int
    let minute: Int
    let dayOffset: Int?
}

public func schedulerDay(start: SchedulerTime, action: @escaping () -> Void) {
    guard let calendar = NSCalendar(identifier: .gregorian) else {
        Log.error("Calendar not found")
        return
    }

    var components = calendar.components([.year, .month, .day, .hour, .minute], from: Date())
    components.hour = start.hours
    components.minute = start.minute

    if let offset = start.dayOffset {
        components.day = (components.day ?? 1) + offset
    }

    startJob(start: start, date: calendar.date(from: components), interval: .days(1), action: action)
}

private func startJob(start: SchedulerTime, date: Date?, interval: Duration, action: @escaping () -> Void) {
    guard let date = date else {
        Log.error("Date not found")
        return
    }

    let difference = date.timeIntervalSince(Date())

    if difference > 0 {
        Log.info("Start job after delay \(difference)")
        startJob(delay: difference, interval: interval, action: action)
    } else {
        Log.info("Start job in next day \(difference)")
        let nextDayStart = SchedulerTime(hours: start.hours, minute: start.minute, dayOffset: 1)
        schedulerDay(start: nextDayStart, action: action)
    }
}


private func startJob(delay: Double, interval: Duration, action: @escaping () -> Void) {
    if delay == 0 {
        startJob(interval: interval, action: action)
    } else {
        Jobs.oneoff(delay: .seconds(delay)) {
            startJob(interval: interval, action: action)
        }
    }
}

private func startJob(interval: Duration, action: @escaping () -> Void) {
    Log.info("schedule job by interval \(interval)")

    Jobs.add(interval: interval) {
        Log.info("job by interval \(interval)")
        action()
    }
}
