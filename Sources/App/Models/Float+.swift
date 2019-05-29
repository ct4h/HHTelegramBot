//
//  Float+.swift
//  App
//
//  Created by basalaev on 29/05/2019.
//

import Foundation

extension Float {

    var hoursString: String {
        let hours = Int(self)
        var minute = String(Int((self - Float(hours)) * 60))
        if minute.count == 1 {
            minute = "0" + minute
        }
        return "\(hours):\(minute)"
    }

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
}
