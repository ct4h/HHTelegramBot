//
//  Date.swift
//  App
//
//  Created by basalaev on 29/01/2019.
//

import Foundation

extension Date {

    static var stringYYYYMMdd: String {
        return DateFormatter.YYYYMMdd.string(from: Date())
    }
}

private extension DateFormatter {

    static var YYYYMMdd: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "YYYY-MM-dd"
        return formatter
    }
}
