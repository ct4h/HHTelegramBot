//
//  Array+.swift
//  App
//
//  Created by basalaev on 23/02/2019.
//

import Foundation

extension Array {
    
    subscript (safe index: Int) -> Element? {
        return (0..<count).contains(index) ? self[index] : nil
    }
}
