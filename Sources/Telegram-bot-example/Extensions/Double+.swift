//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 05.06.2024.
//

import Foundation

extension Double {
    var hoursString: String {
        let hours = Int(self)
        var minute = String(Int((self - Double(hours)) * 60))
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
        } else if self >= 6 {
            return "🐌"
        } else if self >= 4 {
            return "🕓"
        } else {
            return "💔"
        }
    }
}
