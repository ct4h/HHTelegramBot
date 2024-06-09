//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 01.06.2024.
//

import Foundation

extension Date {
    static var stringYYYYMMdd: String {
        return Date().stringYYYYMMdd
    }

    var stringYYYYMMdd: String {
        return DateFormatter.yyyyMMdd.string(from: self)
    }

    var zeroTimeDate: Date? {
        guard let calendar = NSCalendar(identifier: .gregorian) else {
            return nil
        }

        var components = calendar.components([.year, .month, .day, .hour, .minute, .second], from: self)
        components.hour = 0
        components.minute = 0
        components.second = 0

        return calendar.date(from: components)
    }
}

extension DateFormatter {

    static var yyyyMMdd: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
