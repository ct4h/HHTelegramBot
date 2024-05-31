//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 30.05.2024.
//

import Foundation

extension String {
    var params: [String] {
        return components(separatedBy: ",")
            .map { $0.replacingOccurrences(of: "\"", with: "") }
    }
}
