//
//  Date.swift
//  App
//
//  Created by basalaev on 29/01/2019.
//

import Foundation

extension Date {

    static var stringYYYYMMdd: String {
        return Date().stringYYYYMMdd
    }

    var stringYYYYMMdd: String {
        return DateFormatter.yyyyMMdd.string(from: self)
    }

    var range: (prev: Date, next: Date)? {
        guard let calendar = NSCalendar(identifier: .gregorian) else {
            return nil
        }

        var components = calendar.components([.year, .month, .day], from: self)

        guard let prevDate = calendar.date(from: components) else {
            return nil
        }

        components.day = (components.day ?? 0) + 1

        guard let nextDate = calendar.date(from: components) else {
            return nil
        }

        return (prevDate, nextDate)
    }
}

extension DateFormatter {

    static var yyyyMMdd: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
