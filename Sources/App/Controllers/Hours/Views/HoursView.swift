//
//  HoursView.swift
//  App
//
//  Created by basalaev on 08.01.2020.
//

import Foundation

protocol HoursView {
    func convert(responses: [HoursResponse], request: HoursRequest) -> [String]
}
