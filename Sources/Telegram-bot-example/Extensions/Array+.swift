//
//  File.swift
//  
//
//  Created by Aleksandr Basalaev on 30.05.2024.
//

import Foundation

extension Array {
    subscript (safe index: Int) -> Element? {
        return (0..<count).contains(index) ? self[index] : nil
    }
}

extension Array where Element == String {
    subscript(safe key: String) -> Element? {
        guard let element = first(where: { $0.starts(with: key) }) else {
            return nil
        }

        return element.replacingOccurrences(of: "\(key) ", with: "")
    }
}
