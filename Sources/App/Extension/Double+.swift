//
//  Double+.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

extension Double {

    var hoursIcon: String {
        if self == 0 {
            return "💩"
        } else if self >= 14 {
            return "☠️"
        } else if self >= 10 {
            return "🤖"
        } else if self >= 8.5 {
            return "👑"
        } else if self >= 7.5 {
            return "✅"
        } else {
            return "💔"
        }
    }

    func format(f: String = ".2") -> String {
        return String(format: "%\(f)f", self)
    }
}
