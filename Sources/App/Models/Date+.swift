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
}

private extension DateFormatter {

    static var yyyyMMdd: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
