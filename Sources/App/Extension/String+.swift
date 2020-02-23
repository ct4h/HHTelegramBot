//
//  String+.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

extension String {
    var params: [String] {
        return components(separatedBy: ",")
            .map { $0.replacingOccurrences(of: "\"", with: "") }
    }
}
